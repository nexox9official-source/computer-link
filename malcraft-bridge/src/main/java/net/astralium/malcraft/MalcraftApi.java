package net.astralium.malcraft;

import dan200.computercraft.api.lua.IComputerSystem;
import dan200.computercraft.api.lua.ILuaAPI;
import dan200.computercraft.api.lua.LuaFunction;

import java.util.Map;

public final class MalcraftApi implements ILuaAPI {
    private final IComputerSystem computer;
    private int tickCounter;

    public MalcraftApi(IComputerSystem computer) {
        this.computer = computer;
    }

    @Override
    public String[] getNames() {
        return new String[]{"malcraft_bus"};
    }

    @Override
    public void startup() {
        MalcraftRegistry.attach(computer);
    }

    @Override
    public void shutdown() {
        MalcraftRegistry.detach(computer.getID(), computer);
    }

    @Override
    public void update() {
        if (++tickCounter >= 20) {
            tickCounter = 0;
            MalcraftRegistry.touch(computer);
        }
    }

    @LuaFunction
    public final int getComputerId() {
        return computer.getID();
    }

    @LuaFunction
    public final String version() {
        return "0.11.0";
    }

    @LuaFunction
    public final boolean isInfected() {
        return MalcraftRegistry.isInfected(computer);
    }

    @LuaFunction
    public final String state() {
        return MalcraftRegistry.selfStateJson(computer);
    }

    @LuaFunction
    public final boolean infectSelf(String source) {
        return MalcraftRegistry.infect(computer, computer.getID(), source, true);
    }

    @LuaFunction
    public final boolean cleanSelf() {
        return MalcraftRegistry.clean(computer, computer.getID());
    }

    @LuaFunction
    public final boolean acknowledgeClean() {
        return MalcraftRegistry.acknowledgeClean(computer);
    }

    @LuaFunction
    public final boolean infectTarget(int targetId, String source) {
        return MalcraftRegistry.infect(computer, targetId, source, true);
    }

    @LuaFunction
    public final boolean cleanTarget(int targetId) {
        return MalcraftRegistry.clean(computer, targetId);
    }

    @LuaFunction
    public final boolean setSpreadTarget(int targetId, boolean enabled) {
        return MalcraftRegistry.setSpread(computer, targetId, enabled);
    }

    @LuaFunction
    public final String listInfected() {
        return MalcraftRegistry.listInfectedJson(computer);
    }

    @LuaFunction
    public final String listComputers() {
        return MalcraftRegistry.listLiveJson(computer);
    }

    @LuaFunction
    public final String nearby(double radius) {
        return MalcraftRegistry.nearbyJson(computer, radius);
    }

    @LuaFunction
    public final boolean heartbeat(boolean spread, String source) {
        return MalcraftRegistry.heartbeat(computer, spread, source);
    }

    @LuaFunction
    public final boolean send(int targetId, String requestId, String action, String payloadJson) {
        return MalcraftRegistry.send(computer, targetId, requestId, action, payloadJson);
    }

    @LuaFunction
    public final boolean reply(int operatorId, String requestId, boolean ok, String payloadJson, String error) {
        return MalcraftRegistry.reply(computer, operatorId, requestId, ok, payloadJson, error);
    }

    @LuaFunction
    public final boolean publishScreen(String frameJson) {
        return MalcraftRegistry.publishScreen(computer, frameJson);
    }

    @LuaFunction
    public final Map<String, Object> getScreen(int targetId) {
        return MalcraftRegistry.getScreen(computer, targetId);
    }

    @LuaFunction
    public final boolean power(int targetId, String action) {
        return MalcraftRegistry.power(computer, targetId, action);
    }
}
