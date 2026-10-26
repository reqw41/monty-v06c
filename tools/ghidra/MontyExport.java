// postScript: выгружает функции, диапазоны кода и декомпиляцию.
// Аргументы: <каталог вывода>. Входы размечает preScript MontyEntries.
import ghidra.app.script.GhidraScript;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.app.cmd.function.CreateFunctionCmd;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;

public class MontyExport extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        File out = new File(a[0]);
        out.mkdirs();

        Listing L = currentProgram.getListing();
        try (PrintWriter w = new PrintWriter(new File(out, "functions.txt"))) {
            for (Function f : L.getFunctions(true))
                w.printf("%s %5d %s%n", f.getEntryPoint(), f.getBody().getNumAddresses(), f.getName());
        }
        try (PrintWriter w = new PrintWriter(new File(out, "code_ranges.txt"))) {
            AddressSetView s = currentProgram.getListing()
                .getInstructions(true).hasNext() ? codeSet(L) : new AddressSet();
            for (AddressRange r : s) w.printf("%s %s%n", r.getMinAddress(), r.getMaxAddress());
        }
        DecompInterface di = new DecompInterface();
        di.openProgram(currentProgram);
        try (PrintWriter w = new PrintWriter(new File(out, "decomp.c"))) {
            for (Function f : L.getFunctions(true)) {
                DecompileResults r = di.decompileFunction(f, 60, monitor);
                w.printf("// ==== %s @ %s%n", f.getName(), f.getEntryPoint());
                if (r != null && r.decompileCompleted())
                    w.println(r.getDecompiledFunction().getC());
                else w.println("// (не декомпилировалась)");
            }
        }
    }
    AddressSet codeSet(Listing L) {
        AddressSet s = new AddressSet();
        for (Instruction ins : L.getInstructions(true))
            s.add(ins.getMinAddress(), ins.getMaxAddress());
        return s;
    }
}
