package net.astralium.malcraft;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;
import dan200.computercraft.api.lua.IComputerSystem;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.storage.LevelResource;

import java.io.IOException;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;

final class MalcraftRegistry {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static final Type STORE_TYPE = new TypeToken<Map<Integer, HostRecord>>() {}.getType();

    private static final Map<Integer, IComputerSystem> LIVE = new ConcurrentHashMap<>();
    private static final Map<Integer, HostRecord> INFECTED = new ConcurrentHashMap<>();
    private static final Map<String, PendingRequest> PENDING = new ConcurrentHashMap<>();
    private static final Map<Integer, ScreenFrame> SCREENS = new ConcurrentHashMap<>();
    private static final long METADATA_SAVE_INTERVAL_MS = 15_000L;

    private static MinecraftServer currentServer;
    private static boolean loaded;

    private MalcraftRegistry() {}

    static void attach(IComputerSystem computer) {
        ensureLoaded(computer);

        int id = computer.getID();
        var record = INFECTED.get(id);

        // If a Computer block was broken and a replacement at the exact same
        // Minecraft position received a new CC:Tweaked ID, migrate the
        // infection record. This is intentionally limited to an offline,
        // infected host at the same block position.
        if (record == null && !isOperatorId(id)) {
            var migrated = findOfflineInfectedAt(computer);
            if (migrated != null && migrated.id != id) {
                int oldId = migrated.id;
                INFECTED.remove(oldId);
                migrated.id = id;
                migrated.source = "replaced:" + oldId + ":" + safe(migrated.source);
                record = migrated;
                INFECTED.put(id, migrated);
                save(computer);
            }
        }

        LIVE.put(id, computer);
        touch(computer);

        record = INFECTED.get(id);
        if (record != null) {
            try {
                computer.queueEvent(
                    "malcraft_bus_state",
                    record.infected,
                    record.infected && record.spread,
                    safe(record.source)
                );
            } catch (RuntimeException ignored) {
            }
        }
    }

    static void detach(int id, IComputerSystem computer) {
        LIVE.remove(id, computer);
        SCREENS.remove(id);

        var record = INFECTED.get(id);
        if (record != null) {
            record.online = false;
            record.lastSeen = System.currentTimeMillis();
            save(computer);
        }
    }

    static void touch(IComputerSystem computer) {
        ensureLoaded(computer);

        var record = INFECTED.get(computer.getID());
        if (record == null) return;

        long now = System.currentTimeMillis();
        record.online = true;
        record.lastSeen = now;
        record.label = computer.getLabel();
        record.dimension = computer.getLevel().dimension().location().toString();
        var pos = computer.getPosition();
        record.x = pos.getX();
        record.y = pos.getY();
        record.z = pos.getZ();

        if (now - record.lastPersisted >= METADATA_SAVE_INTERVAL_MS) {
            record.lastPersisted = now;
            save(computer);
        }
    }

    static boolean isInfected(IComputerSystem computer) {
        ensureLoaded(computer);
        var record = INFECTED.get(computer.getID());
        return record != null && record.infected;
    }

    static String selfStateJson(IComputerSystem computer) {
        ensureLoaded(computer);

        var record = INFECTED.get(computer.getID());
        var root = new LinkedHashMap<String, Object>();

        root.put("known", record != null);
        root.put("infected", record != null && record.infected);
        root.put("spread", record != null && record.spread);
        root.put("source", record == null ? "" : safe(record.source));
        return GSON.toJson(root);
    }

    static boolean infect(IComputerSystem caller, int targetId, String source, boolean spread) {
        ensureLoaded(caller);

        int callerId = caller.getID();
        if (targetId != callerId && !canSpread(callerId)) return false;
        if (isOperatorId(targetId)) return false;

        var record = INFECTED.computeIfAbsent(targetId, HostRecord::new);
        record.infected = true;
        record.spread = spread;
        record.source = safe(source);
        record.infectedAt = record.infectedAt == 0 ? System.currentTimeMillis() : record.infectedAt;
        record.lastSeen = System.currentTimeMillis();

        var live = LIVE.get(targetId);
        if (live != null) {
            record.online = true;
            record.label = live.getLabel();
            record.dimension = live.getLevel().dimension().location().toString();
            var pos = live.getPosition();
            record.x = pos.getX();
            record.y = pos.getY();
            record.z = pos.getZ();

            try {
                live.queueEvent("malcraft_bus_state", true, spread, record.source);
            } catch (RuntimeException ignored) {
            }
        }

        save(caller);
        return true;
    }

    static boolean clean(IComputerSystem caller, int targetId) {
        ensureLoaded(caller);

        if (!isOperator(caller)) return false;

        var record = INFECTED.computeIfAbsent(targetId, HostRecord::new);
        record.infected = false;
        record.spread = false;
        record.source = "cleaned";
        record.lastSeen = System.currentTimeMillis();
        SCREENS.remove(targetId);

        var live = LIVE.get(targetId);
        if (live != null) {
            try {
                live.queueEvent("malcraft_bus_state", false, false, "cleaned");
            } catch (RuntimeException ignored) {
            }
        }

        save(caller);
        return true;
    }

    static boolean acknowledgeClean(IComputerSystem computer) {
        ensureLoaded(computer);

        int id = computer.getID();
        var record = INFECTED.get(id);
        if (record == null || record.infected) return false;

        INFECTED.remove(id);
        SCREENS.remove(id);
        save(computer);
        return true;
    }

    static boolean setSpread(IComputerSystem caller, int targetId, boolean enabled) {
        ensureLoaded(caller);
        if (!isOperator(caller)) return false;

        var record = INFECTED.get(targetId);
        if (record == null || !record.infected) return false;

        record.spread = enabled;

        var live = LIVE.get(targetId);
        if (live != null) {
            try {
                live.queueEvent("malcraft_bus_state", true, enabled, safe(record.source));
            } catch (RuntimeException ignored) {
            }
        }

        save(caller);
        return true;
    }

    static boolean heartbeat(IComputerSystem computer, boolean spread, String source) {
        ensureLoaded(computer);

        var record = INFECTED.get(computer.getID());
        if (record == null || !record.infected) return false;

        record.spread = spread;
        if (source != null && !source.isBlank()) record.source = source;
        touch(computer);
        return true;
    }

    static String listInfectedJson(IComputerSystem caller) {
        ensureLoaded(caller);
        if (!isOperator(caller)) return "{\"hosts\":[],\"disks\":[]}";

        long now = System.currentTimeMillis();
        var hosts = new ArrayList<Map<String, Object>>();

        INFECTED.values().stream()
            .filter(record -> record.infected)
            .sorted(Comparator.comparingInt(record -> record.id))
            .forEach(record -> {
                var row = new LinkedHashMap<String, Object>();
                row.put("computer_id", record.id);
                row.put("infected", true);
                row.put("spread", record.spread);
                row.put("source", safe(record.source));
                row.put("label", safe(record.label));
                row.put("last_seen", Math.floorDiv(record.lastSeen, 1000));
                row.put("online", LIVE.containsKey(record.id) && now - record.lastSeen <= 5000);
                row.put("dimension", safe(record.dimension));
                row.put("x", record.x);
                row.put("y", record.y);
                row.put("z", record.z);
                hosts.add(row);
            });

        var root = new LinkedHashMap<String, Object>();
        root.put("hosts", hosts);
        root.put("disks", List.of());
        root.put("transport", "malcraft_bridge");
        return GSON.toJson(root);
    }

    static String nearbyJson(IComputerSystem caller, double radius) {
        ensureLoaded(caller);

        int callerId = caller.getID();
        if (!isOperator(caller) && !canSpread(callerId)) return "[]";

        radius = Math.max(0.5, Math.min(radius, 64.0));
        double radiusSq = radius * radius;
        var callerLevel = caller.getLevel();
        var callerPos = caller.getPosition();

        var result = new ArrayList<Map<String, Object>>();

        for (var entry : LIVE.entrySet()) {
            int targetId = entry.getKey();
            if (targetId == callerId || isOperatorId(targetId)) continue;

            var target = entry.getValue();
            if (target.getLevel() != callerLevel) continue;

            var pos = target.getPosition();
            double dx = pos.getX() - callerPos.getX();
            double dy = pos.getY() - callerPos.getY();
            double dz = pos.getZ() - callerPos.getZ();
            double distanceSq = dx * dx + dy * dy + dz * dz;

            if (distanceSq > radiusSq) continue;

            var row = new LinkedHashMap<String, Object>();
            row.put("id", targetId);
            row.put("label", safe(target.getLabel()));
            row.put("distance", Math.sqrt(distanceSq));
            row.put("infected", isInfected(target));
            result.add(row);
        }

        result.sort(Comparator.comparingDouble(row -> ((Number) row.get("distance")).doubleValue()));
        return GSON.toJson(result);
    }

    static boolean send(
        IComputerSystem caller,
        int targetId,
        String requestId,
        String action,
        String payloadJson
    ) {
        ensureLoaded(caller);
        if (!isOperator(caller)) return false;

        var record = INFECTED.get(targetId);
        if (record == null || !record.infected) return false;

        var target = LIVE.get(targetId);
        if (target == null) return false;

        String key = pendingKey(caller.getID(), requestId);
        PENDING.put(key, new PendingRequest(caller.getID(), targetId, System.currentTimeMillis()));

        try {
            target.queueEvent(
                "malcraft_bus_command",
                caller.getID(),
                requestId,
                safe(action),
                safe(payloadJson)
            );
            return true;
        } catch (RuntimeException error) {
            PENDING.remove(key);
            return false;
        }
    }

    static boolean reply(
        IComputerSystem caller,
        int operatorId,
        String requestId,
        boolean ok,
        String payloadJson,
        String error
    ) {
        ensureLoaded(caller);

        String key = pendingKey(operatorId, requestId);
        var pending = PENDING.get(key);

        if (pending == null || pending.targetId != caller.getID()) return false;
        if (!isInfected(caller)) return false;

        var operator = LIVE.get(operatorId);
        if (operator == null || !isOperatorId(operatorId)) {
            PENDING.remove(key);
            return false;
        }

        PENDING.remove(key);

        try {
            operator.queueEvent(
                "malcraft_bus_response",
                caller.getID(),
                requestId,
                ok,
                safe(payloadJson),
                safe(error)
            );
            return true;
        } catch (RuntimeException ignored) {
            return false;
        }
    }

    static boolean publishScreen(IComputerSystem caller, String frameJson) {
        ensureLoaded(caller);
        if (!isInfected(caller)) return false;

        SCREENS.put(
            caller.getID(),
            new ScreenFrame(safe(frameJson), System.currentTimeMillis())
        );
        touch(caller);
        return true;
    }

    static Map<String, Object> getScreen(IComputerSystem caller, int targetId) {
        ensureLoaded(caller);
        if (!isOperator(caller)) return Map.of();

        var record = INFECTED.get(targetId);
        if (record == null || !record.infected) return Map.of();

        var frame = SCREENS.get(targetId);
        if (frame == null) return Map.of();

        return Map.of(
            "frame", frame.json,
            "updated_at", frame.updatedAt
        );
    }

    static boolean power(IComputerSystem caller, int targetId, String action) {
        ensureLoaded(caller);
        if (!isOperator(caller)) return false;

        var record = INFECTED.get(targetId);
        if (record == null || !record.infected) return false;

        String normalized = safe(action).toLowerCase();
        String command;

        switch (normalized) {
            case "on", "turn-on", "turnon" -> command = "computercraft turn-on #" + targetId;
            case "off", "shutdown" -> command = "computercraft shutdown #" + targetId;
            default -> {
                return false;
            }
        }

        var server = caller.getLevel().getServer();
        if (server == null) return false;

        server.execute(() -> server.getCommands().performPrefixedCommand(
            server.createCommandSourceStack().withPermission(4),
            command
        ));

        return true;
    }

    private static HostRecord findOfflineInfectedAt(IComputerSystem computer) {
        String dimension = computer.getLevel().dimension().location().toString();
        var pos = computer.getPosition();

        for (var record : INFECTED.values()) {
            if (!record.infected || LIVE.containsKey(record.id)) continue;
            if (!Objects.equals(record.dimension, dimension)) continue;
            if (record.x == pos.getX() && record.y == pos.getY() && record.z == pos.getZ()) {
                return record;
            }
        }
        return null;
    }

    private static boolean canSpread(int callerId) {
        if (isOperatorId(callerId)) return true;

        var record = INFECTED.get(callerId);
        return record != null && record.infected && record.spread;
    }

    private static boolean isOperator(IComputerSystem computer) {
        return isOperatorId(computer.getID());
    }

    private static boolean isOperatorId(int id) {
        return id == 0;
    }

    private static String pendingKey(int operatorId, String requestId) {
        return operatorId + ":" + safe(requestId);
    }

    private static String safe(String value) {
        return value == null ? "" : value;
    }

    private static synchronized void ensureLoaded(IComputerSystem computer) {
        var server = computer.getLevel().getServer();
        if (server == null) return;

        if (currentServer != server) {
            currentServer = server;
            loaded = false;
            LIVE.clear();
            INFECTED.clear();
            PENDING.clear();
            SCREENS.clear();
        }

        if (loaded) return;
        loaded = true;

        Path path = storePath(server);
        if (!Files.exists(path)) return;

        try {
            String json = Files.readString(path, StandardCharsets.UTF_8);
            Map<Integer, HostRecord> stored = GSON.fromJson(json, STORE_TYPE);
            if (stored != null) {
                for (var record : stored.values()) {
                    record.online = false;
                    record.lastPersisted = 0L;
                }
                INFECTED.putAll(stored);
            }
        } catch (Exception ignored) {
        }
    }

    private static synchronized void save(IComputerSystem computer) {
        var server = computer.getLevel().getServer();
        if (server == null) return;

        Path path = storePath(server);

        try {
            Files.createDirectories(path.getParent());
            Files.writeString(path, GSON.toJson(new HashMap<>(INFECTED)), StandardCharsets.UTF_8);
        } catch (IOException ignored) {
        }
    }

    private static Path storePath(MinecraftServer server) {
        return server.getWorldPath(LevelResource.ROOT)
            .resolve("data")
            .resolve("malcraft_bridge_hosts.json");
    }

    private static final class HostRecord {
        int id;
        boolean infected = true;
        boolean spread = true;
        String source = "";
        long infectedAt;
        long lastSeen;
        String label = "";
        String dimension = "";
        int x;
        int y;
        int z;
        transient boolean online;
        transient long lastPersisted;

        HostRecord(int id) {
            this.id = id;
        }
    }

    private record PendingRequest(int operatorId, int targetId, long createdAt) {}
    private record ScreenFrame(String json, long updatedAt) {}
}
