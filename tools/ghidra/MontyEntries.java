// preScript: размечает входы ДО автоанализа (иначе он успевает объявить там данные).
// Аргументы: <hex-вход>...
import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.app.cmd.function.CreateFunctionCmd;
import ghidra.program.model.address.*;

public class MontyEntries extends GhidraScript {
    @Override
    public void run() throws Exception {
        AddressSpace sp = currentProgram.getAddressFactory().getDefaultAddressSpace();
        for (String s : getScriptArgs()) {
            Address ad = sp.getAddress(Long.parseLong(s, 16));
            new DisassembleCommand(ad, null, true).applyTo(currentProgram, monitor);
            new CreateFunctionCmd(ad).applyTo(currentProgram, monitor);
            currentProgram.getSymbolTable().addExternalEntryPoint(ad);
        }
    }
}
