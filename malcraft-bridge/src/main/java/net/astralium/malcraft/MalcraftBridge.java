package net.astralium.malcraft;

import dan200.computercraft.api.ComputerCraftAPI;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.event.lifecycle.FMLCommonSetupEvent;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(MalcraftBridge.MOD_ID)
public final class MalcraftBridge {
    public static final String MOD_ID = "malcraft_bridge";

    public MalcraftBridge() {
        FMLJavaModLoadingContext.get().getModEventBus().addListener(this::commonSetup);
    }

    private void commonSetup(FMLCommonSetupEvent event) {
        event.enqueueWork(() -> ComputerCraftAPI.registerAPIFactory(MalcraftApi::new));
    }
}
