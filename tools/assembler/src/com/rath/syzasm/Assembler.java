
package com.rath.syzasm;

import java.io.DataOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Scanner;

import com.rath.syzasm.util.VariableFetcher;
import com.rath.syzasm.vals.ALUInstr;
import com.rath.syzasm.vals.IOInstr;
import com.rath.syzasm.vals.JumpInstr;
import com.rath.syzasm.vals.Opcodes;
import com.rath.syzasm.vals.SysInstr;

public class Assembler {
  
  /**
   * Assembles a .syz file into machine code for the SyzygyB100 CPU.
   * 
   * @param args 0: .syz file.
   */
  public static void main(String[] args) {
    
    if (args.length > 0) {
      final File asmFile = new File(args[0]);
      assemble(asmFile);
    } else {
      printUsage();
    }
  }
  
  /**
   * Assembles a .syz source file into binary.
   * 
   * @param asmFile the .syz file to be assembled.
   */
  private static final void assemble(final File asmFile) {
    
    final HashMap<String, Short> labels = parseLabels(asmFile);
    final ArrayList<Short> instr = parseInstructions(asmFile, labels);
    
    final String fileName = asmFile.getName().substring(0, asmFile.getName().lastIndexOf('.'));
    writeToFile(instr, fileName);
    
  }
  
  /**
   * Finds all jump labels in a .syz assembly file.
   * 
   * @param asmFile the assembly file.
   * @return A HashMap that maps Label -> Line number.
   */
  private static final HashMap<String, Short> parseLabels(final File asmFile) {
    
    // Open a scanner on the file
    Scanner fscan = null;
    try {
      fscan = new Scanner(asmFile);
    } catch (IOException ioe) {
      ioe.printStackTrace();
    }
    
    // Keep track of the label map and current line
    final HashMap<String, Short> result = new HashMap<String, Short>();
    short currInstr = 0;
    
    // Go through each line
    while (fscan.hasNextLine()) {
      
      // Get the line, ignore comments and empty lines
      final String line = fscan.nextLine().trim();
      
      // System.out.print("Line: \"" + line + "\": ");
      
      if (line.startsWith("#") || line.length() < 2) {
        // System.out.println("Not an instruction.");
        continue;
      }
      
      // If it's a valid label (starts with ":"), add it to the map
      if (line.startsWith(":")) {
        final String label = line.substring(1);
        // System.out.println("Found label: \"" + label + "\".");
        result.put(label, currInstr);
        System.out.println("Added \"" + label + "\" to labels at instruction " + currInstr + ".");
      } else {
        currInstr++;
        // System.out.println("Valid instruction. Count: " + currInstr + ".");
      }
      
    }
    
    return result;
  }
  
  /**
   * Parses all instructions in an assembly file.
   * 
   * @param asmFile a handle to the input assembly file.
   * @param labels a Map of labels in the assembly file -> instruction number.
   * @return a list of 16-bit binary instructions.
   */
  private static final ArrayList<Short> parseInstructions(final File asmFile,
      final HashMap<String, Short> labels) {
    
    // Open a scanner on the file
    Scanner fscan = null;
    try {
      fscan = new Scanner(asmFile);
    } catch (IOException ioe) {
      ioe.printStackTrace();
    }
    
    // Build list of instructions
    final ArrayList<Short> result = new ArrayList<Short>();
    int currLine = 0;
    
    // Scan through the assembly file
    while (fscan.hasNextLine()) {
      
      currLine++;
      final String line = fscan.nextLine().trim();
      if (line == null || line.startsWith("#") || line.length() < 2 || line.startsWith(":"))
        continue;
      
      // Send the current line to the instruction parser
      final short instr = parseInstruction(line, labels, currLine);
      result.add(instr);
    }
    
    return result;
  }
  
  /**
   * Parses an instruction that spans one line and encodes it as a short.
   * 
   * @param line the instruction as a String.
   * @param labels the label map.
   * @param currLine the current line number.
   * @return a two-byte machine code version of this instruction.
   */
  public static final short parseInstruction(final String line, final HashMap<String, Short> labels,
      final int currLine) {
    
    short binInstr = 0;
    if (line == null) {
      throw new IllegalArgumentException("Line is too short or empty (line " + line + ").");
    }
    
    // If there's only one string on this line (jump or ALU instruction)
    if (line.trim().indexOf(' ') < 0) {
      
      if (line.startsWith("j")) {
        binInstr = parseJump(line, currLine);
      } else if (ALUInstr.INSTR_MAP.keySet().contains(line)) {
        binInstr = parseALUInstr(line, currLine);
      } else {
        throw new IllegalArgumentException("Not a valid instruction (line " + currLine + ").");
      }
      
    } else {
      
      final String[] operation = line.split("\\s+", 2);
      
      if (operation[0].trim().startsWith("io")) {
        binInstr = parseIOInstr(line, currLine);
        
      } else {
        
        switch (operation[0].trim().toLowerCase()) {
          case "push":
            binInstr = parsePush(operation[1], labels, currLine);
          break;
          case "copy":
            binInstr = parseCopy(operation[1], currLine);
          break;
          case "sys":
            binInstr = parseSys(operation[1], currLine);
          break;
          default:
        }
      }
    }
    
    return binInstr;
  }
  
  /**
   * Parses the push instruction.
   * 
   * @param pstr the line containing the push instruction.
   * @return the machine code as two bytes.
   */
  private static final short parsePush(final String pargs, final HashMap<String, Short> labels,
      final int line) {
    
    // Ensure correct argument count
    if (pargs.trim().indexOf(' ') > 0) throw new IllegalArgumentException(
        "Push instruction does not have only one argument (line " + line + ").");
    
    // Decode the argument
    short num = Opcodes.PUSH;
    
    if (isNumber(pargs)) {
      
      // If it's just a normal number
      final short argNum = Short.decode(pargs);
      if (argNum < 0) {
        throw new IllegalArgumentException("Push cannot be negative (line " + line + ").");
      }
      num |= argNum;
    } else if (pargs.trim().startsWith("$lbl.")) {
      
      // If it's a label (look it up)
      final String[] lbls = pargs.split("\\.", 2);
      if (lbls.length != 2) {
        throw new IllegalArgumentException("Invalid label (line " + line + ").");
      }
      final String lbl = lbls[1];
      final Short lblValue = labels.get(lbl);
      if (lblValue == null) {
        throw new IllegalArgumentException("Referenced label does not exist (line " + line + ").");
      }
      num |= (short) lblValue;
    } else {
      
      // Otherwise, it's probably a config value, so look it up
      final String lookupStr = VariableFetcher.lookup(pargs);
      if (lookupStr != null) {
        num |= Short.decode(lookupStr);
      } else {
        throw new IllegalArgumentException(
            "Push instruction's value is not valid (line " + line + ").");
      }
    }
    
    return num;
  }
  
  /**
   * Performs parsing on a copy instruction.
   * 
   * @param args the tokens after the copy keyword.
   * @param line the line number.
   * @return a 16-bit machine instruction representation of the copy instruction.
   */
  private static final short parseCopy(final String args, final int line) {
    
    // Ensure copy arguments match syntax and get tokens
    if (!args.trim().matches("\\s*\\d{1,2}\\s*,\\s*\\d{1,2}"))
      throw new IllegalArgumentException("Invalid copy instruction syntax (line " + line + ").");
    final String[] tokens = args.split("\\s*,\\s*");
    
    // Set the instruction's opcode to copy.
    short num = Opcodes.COPY;
    
    // Parse and check range of first argument (source register)
    short argSrc = Short.parseShort(tokens[0].trim());
    if (argSrc < 0 || argSrc > 15) throw new IllegalArgumentException(
        "Source register for copy instruction out of range (line " + line + ").");
    
    // Parse and check range of second argument (destination register)
    short argDest = Short.parseShort(tokens[1].trim());
    if (argDest < 0 || argDest > 15) throw new IllegalArgumentException(
        "Source register for copy instruction out of range (line " + line + ").");
    
    // Set the arguments in the machine code
    num |= (argSrc << 8);
    num |= (argDest << 4);
    
    return num;
  }
  
  /**
   * Parses a jump instruction into 16-bit binary machine code.
   * 
   * @param str the instruction.
   * @param line the line number.
   * @return the two byte instruction as a short.
   */
  private static final short parseJump(final String str, final int line) {
    
    // Ensure only one token
    if (str.trim().indexOf(' ') >= 0) {
      throw new IllegalArgumentException("Jump instruction is invalid (line " + line + ").");
    }
    
    short num = Opcodes.JUMP;
    
    switch (str) {
      case "jmp":
        num |= JumpInstr.JMP;
      break;
      case "jeq":
        num |= JumpInstr.JEQ;
      break;
      case "jne":
        num |= JumpInstr.JNE;
      break;
      case "jlt":
        num |= JumpInstr.JLT;
      break;
      case "jle":
        num |= JumpInstr.JLE;
      break;
      case "jgt":
        num |= JumpInstr.JGT;
      break;
      case "jge":
        num |= JumpInstr.JGE;
      break;
      default:
        throw new IllegalArgumentException("Jump instruction is invalid (line " + line + ").");
    }
    
    return num;
  }
  
  /**
   * Parses an ALU instruction into a 16-bit machine instruction.
   * 
   * @param str the instruction.
   * @param line the current line.
   * @return the two bytes that make up this instruction.
   */
  private static final short parseALUInstr(final String str, final int line) {
    short num = Opcodes.ALU;
    num |= ALUInstr.INSTR_MAP.get(str);
    return num;
  }
  
  /**
   * Parses an I/O instruction into machine code.
   * 
   * @param str the instruction.
   * @param line the current line number.
   * @return the two bytes that make up this instruction.
   */
  private static final short parseIOInstr(final String str, final int line) {
    
    short num = Opcodes.IO;
    
    final String[] opTokens = str.split("\\s+", 2);
    if (opTokens.length < 2) {
      throw new IllegalArgumentException("Invalid I/O instruction syntax (line " + line + ").");
    }
    
    // Get the interface number and check its range
    short pid = -1;
    final int commaIdx = opTokens[1].indexOf(',');
    
    // For two arguments
    if (commaIdx > 0) {
      
      final String regStr = opTokens[1].trim().toLowerCase().substring(0, commaIdx).trim();
      
      try {
        if (regStr.startsWith("0x")) {
          pid = Short.parseShort(regStr.substring(2), 16);
        } else {
          pid = Short.parseShort(regStr);
        }
      } catch (NumberFormatException nfe) {
        
        // Test if it's a config option
        final String lookupStr = VariableFetcher.lookup(regStr);
        if (lookupStr != null) {
          pid = Short.decode(lookupStr);
        } else {
          throw new IllegalArgumentException(
              "Push instruction's value is not valid (line " + line + ").");
        }
        
      }
    } else {
      
      // For one argument
      final String regStr = opTokens[1].trim().toLowerCase();
      try {
        if (regStr.startsWith("0x")) {
          pid = Short.parseShort(regStr.substring(2), 16);
        } else {
          pid = Short.parseShort(regStr);
        }
      } catch (NumberFormatException nfe) {
        
        // Test if it's a config option
        final String lookupStr = VariableFetcher.lookup(regStr);
        if (lookupStr != null) {
          pid = Short.decode(lookupStr);
        } else {
          throw new IllegalArgumentException(
              "Push instruction's value is not valid (line " + line + ").");
        }
      }
    }
    if (pid < 0 || pid > 7) throw new IllegalArgumentException(
        "I/O interface to execute out of range (line " + line + ").");
    
    // Set peripheral ID bits
    num |= (pid << 8);
    
    short regNum = 0;
    String regToken = "";
    
    switch (opTokens[0].trim()) {
      
      // I/O peripheral execute command
      case "ioex":
        
        // Check argument count
        if (!opTokens[1].trim().matches("\\d{1,2}|\\$conf\\.\\w+\\.\\w+")) {
          throw new IllegalArgumentException(
              "Incorrect number of arguments for ioex (line " + line + ").");
        }
        
        num |= IOInstr.IOEX;
      break;
    
      // I/O peripheral set register command
      case "iosr":
        
        regToken = opTokens[1].trim().substring(commaIdx + 1, opTokens[1].length()).trim();
        
        // Get the register ID to write to.
        try {
          if (regToken.startsWith("0x")) {
            regNum = Short.parseShort(regToken.substring(2), 16);
          } else {
            regNum = Short.parseShort(regToken);
          }
        } catch (NumberFormatException nfe) {
          
          // Test if it's a config option
          final String lookupStr = VariableFetcher.lookup(regToken);
          System.out.println("Fetched \"" + regToken + "\", and got \"" + lookupStr + "\".");
          if (lookupStr != null) {
            regNum = Short.decode(lookupStr);
          } else {
            throw new IllegalArgumentException(
                "I/O interface register is not a valid number (line " + line + ").");
          }
        }
        if (regNum < 0 || regNum > 15) throw new IllegalArgumentException(
            "I/O interface register out of range (line " + line + ").");
        
        // Set peripheral ID and write mode bits
        num |= (regNum << 4) | IOInstr.IOSR;
        
      break;
    
      // I/O peripheral get register value command
      case "iogr":
        
        regToken = opTokens[1].trim().substring(commaIdx + 1, opTokens[1].length()).trim();
        
        // Get the register ID to read from.
        try {
          if (regToken.startsWith("0x")) {
            regNum = Short.parseShort(regToken.substring(2), 16);
          } else {
            regNum = Short.parseShort(regToken);
          }
        } catch (NumberFormatException nfe) {
          
          // Test if it's a config option
          final String lookupStr = VariableFetcher.lookup(regToken);
          System.out.println("Fetched \"" + regToken + "\", and got \"" + lookupStr + "\".");
          if (lookupStr != null) {
            regNum = Short.decode(lookupStr);
          } else {
            throw new IllegalArgumentException(
                "I/O interface register is not a valid number (line " + line + ").");
          }
        }
        if (regNum < 0 || regNum > 15) throw new IllegalArgumentException(
            "I/O interface register out of range (line " + line + ").");
        
        // Set peripheral ID bits
        num |= (regNum << 4);
      break;
      default:
        throw new IllegalArgumentException("Invalid I/O command (line " + line + ").");
    }
    
    return num;
  }
  
  /**
   * Parses a system instruction into machine code.
   * 
   * @param str the instruction's arguments after the "sys" keyword.
   * @param line the current line number.
   * @return the two bytes that make up this instruction.
   */
  private static final short parseSys(final String str, final int line) {
    
    short num = Opcodes.SYS;
    
    // Split args into tokens
    final String[] opTokens = str.split("\\s+");
    if (opTokens.length != 2) {
      throw new IllegalArgumentException("Invalid system instruction (line " + line + ").");
    }
    
    final String opStr = opTokens[0].trim();
    
    // System commands
    if (opStr.equals("cmd")) {
      
      // sys flag $n, $n
      // sys cmd $n
      
      final String cmdName = opTokens[1].toLowerCase().trim();
      
      // Get the command number
      short cmdIndex = -1;
      try {
        cmdIndex = Short.decode(cmdName);
      } catch (NumberFormatException nfe) {
        
        // Check if it's a variable
        final String lookupStr = VariableFetcher.lookup(cmdName);
        System.out.println("Fetched \"" + cmdName + "\", and got \"" + lookupStr + "\".");
        if (lookupStr != null) {
          cmdIndex = Short.decode(lookupStr);
        } else {
          throw new IllegalArgumentException("Invalid system flag (line " + line + ").");
        }
      }
      
      if (cmdIndex < 0 || cmdIndex > 255) {
        throw new IllegalArgumentException("Flag number must be 0-255 (line " + line + ").");
      }
      
      num |= SysInstr.OP_FLAG | cmdIndex;
      
    } else {
      throw new IllegalArgumentException("Unrecognized system command (line " + line + ").");
    }
    
    return num;
  }
  
  /**
   * Writes the list of instructions to a .bin file to be executed on the Syzygy B100 CPU.
   * 
   * @param instr a List of 16-bit instructions.
   * @param fname the file name (sans extension) to output to.
   */
  private static final void writeToFile(final ArrayList<Short> instr, final String fname) {
    
    // Get a handle to the output file
    final File binFile = new File(fname + ".bin");
    DataOutputStream bout = null;
    try {
      bout = new DataOutputStream(new FileOutputStream(binFile));
      
      // Write it to file
      for (short val : instr) {
        bout.writeShort(val);
      }
    } catch (IOException ioe) {
      ioe.printStackTrace();
    }
  }
  
  /**
   * Checks whether or not a String is numeric and can fit within two bytes.
   * 
   * @param str the String to check.
   * @return true if the string is valid; false if not.
   */
  private static final boolean isNumber(final String str) {
    try {
      Short.decode(str);
    } catch (NumberFormatException nfe) {
      return false;
    }
    return true;
  }
  
  /**
   * Prints the usage message.
   */
  private static final void printUsage() {
    System.out.println("Pass in a .syz assembly file as the runtime argument.");
  }
}
