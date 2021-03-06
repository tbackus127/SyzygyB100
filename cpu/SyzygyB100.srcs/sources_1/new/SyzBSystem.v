`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/12/2017 03:09:39 PM
// Design Name: 
// Module Name: SyzBSystem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module SyzBSystem(
    input clk,
    input en,
    input res,
    input [7:0] snoopSelect,
    input miso,
    input ps2Clk,
    input ps2Dat,
    output [15:0] snoopOut,
    output [15:0] ledsOut,
    output [15:0] segsOut,
    output vnMode,
    output serialClock,
    output chipSelect,
    output mosi,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output hSync,
    output vSync
  );
  
  // 2560000: Human-readable clock cycles
  // 1: Normal Safe Clock
  
  // Count this number of memory clock ticks before inverting the CPU clock
  // Clock is divided this many times, plus one.
  parameter CDIV_AMT_CPU = 1;
  
  // Clock Phase: 0 = Fetch Instruction, 1 = Decode & Execute
  //   Starts HI so first tick will be LO.
  reg clockPhaseReg = 1'b1;
  
  // Clock Divider (CPU clock, 4x slower than memory clock)
  wire clockSigCPU;
  ClockDivider cdivcpu (
    .cIn(clk),
    .reqCount(CDIV_AMT_CPU),
    .cOut(clockSigCPU)
  );
  
  // Boot Rom
  wire wVNMode;
  wire [15:0] wProgCountVal;
  wire [15:0] wBootROMOut;
  BootRom brom(
    .readEn(en),
    .addr(wProgCountVal[7:0]),
    .instrOut(wBootROMOut[15:0]),
    .debugOut()
  );
  assign vnMode = wVNMode;
  
  // Memory address input multiplexer
  wire [15:0] wMemAddrIn;
  wire [15:0] wAddrFromMemIntr;
  Mux16B2to1 memAddrInMux(
    .aIn(wProgCountVal[15:0]),
    .bIn(wAddrFromMemIntr[15:0]),
    .sel(clockPhaseReg),
    .dOut(wMemAddrIn[15:0])
  );
  
  // System Memory
  wire [15:0] wDataFromMemIntr;
  wire [15:0] wDataFromMem;
  wire wMemRdFromIntr;
  wire wMemWrFromIntr;
  wire [15:0] wVGAAddr;
  wire [15:0] wPixelData;
  SyzMem mem(
    .en(1'b1),
    .memClk(clk),
    .addr(wMemAddrIn[15:0]),
    .dIn(wDataFromMemIntr[15:0]),
    .readEn(wMemRdFromIntr | ~clockPhaseReg),
    .writeEn(wMemWrFromIntr),
    .vgaClk(clk),
    .vgaAddr(wVGAAddr[15:0]),
    .dOut(wDataFromMem[15:0]),
    .vgaOut(wPixelData[15:0])
  );
  
  // Choose instruction source from Boot ROM or system memory
  wire [15:0] wInstrIn;
  Mux16B2to1 muxInstr(
    .aIn(wBootROMOut[15:0]),
    .bIn(wDataFromMem[15:0]),
    .sel(wVNMode),
    .dOut(wInstrIn[15:0])
  );
  
  // CPU
  wire [31:0] wDataToPeriphs;
  wire [31:0] wDataFromPeriphs;
  wire [3:0] wPeriphSelect;
  wire [3:0] wPeriphRegSelect;
  wire wPeriphRegReadEn;
  wire wPeriphRegWriteEn;
  wire wPeriphExec;
  wire [15:0] wCPUDebugOut;
  SyzygyB100 cpu(
    .clockSig(clockSigCPU),
    .en(en),
    .res(res),
    .extInstrIn(wInstrIn[15:0]),
    .extRegSel(snoopSelect[3:0]),
    .extPCValue(wProgCountVal[15:0]),
    .extPerDIn(wDataFromPeriphs[31:0]),
    .sysClockPhase(clockPhaseReg),
    .vnMode(wVNMode),
    .extPeekValue(wCPUDebugOut[15:0]),
    .extPerDOut(wDataToPeriphs[31:0]),
    .extPerSel(wPeriphSelect[3:0]),
    .extPerReg(wPeriphRegSelect[3:0]),
    .extPerReadEn(wPeriphRegReadEn),
    .extPerWriteEn(wPeriphRegWriteEn),
    .extPerExec(wPeriphExec)
  );
  
  
  //----------------------------------------------------------------------------
  // Peripheral Interfaces
  //
  // Peripheral ID's:
  //   PID=0: LEDs
  //   PID=1: 7-segment display
  //   PID=2: Memory
  //   PID=3: SD Card
  //   PID=4: VGA Output
  //   PID=5: Keyboard Input
  //----------------------------------------------------------------------------
  
  wire [15:0] wPeriphDebugOut;
  
  wire [15:0] wPeriphSelectSignals;
  Dmx4to16 periphIDSelect(
    .sel(wPeriphSelect[3:0]),
    .en(wPeriphRegWriteEn | wPeriphRegReadEn | wPeriphExec),
    .out(wPeriphSelectSignals[15:0])
  );
  
  // LEDs (PID=0)
  // TODO: Make LED interface
  wire [15:0] wLEDIntrOut;
  wire [15:0] wLEDDebugOut;
  LEDInterface ledIntr(
    .cpuClock(clockSigCPU),
    .periphSelect(wPeriphSelectSignals[0]),
    .dIn(wDataToPeriphs[15:0]),
    .regSelect(wPeriphRegSelect[3:0]),
    .readEn(wPeriphRegReadEn),
    .writeEn(wPeriphRegWriteEn),
    .reset(res),
    .exec(wPeriphExec),
    .dOut(wLEDIntrOut[15:0]),
    .ledsOut(ledsOut[15:0]),             // TODO: Used to be ledsOut[15:0]
    .debugOut(wLEDDebugOut[15:0])
  );
  
  // 7-segment display (PID=1)
  // TODO: Make 7Seg interface
  wire [15:0] wSegIntrOut;
  wire [15:0] wSegDebugOut;
  SevSegInterface segIntr(
    .cpuClock(clockSigCPU),
    .periphSelect(wPeriphSelectSignals[1]),
    .dIn(wDataToPeriphs[15:0]),
    .regSelect(wPeriphRegSelect[3:0]),
    .readEn(wPeriphRegReadEn),
    .writeEn(wPeriphRegWriteEn),
    .reset(res),
    .exec(wPeriphExec),
    .dOut(wSegIntrOut[15:0]),
    .segsOut(segsOut[15:0]),
    .debugOut(wSegDebugOut[15:0])
  );
  
  // Memory (PID=2)
  // Debug sources:
  //   SnoopPeriph=1:
  //     Reg=0: R0 (Instruction)
  //     Reg=1: R1 (Status)
  //     Reg=2: R2 (Data-In)
  //     Reg=3: R0 (Data-Out)
  //     Reg=4: R0 (Address)
  wire [31:0] wMemIntrDebugOut;
  wire [15:0] wMemDataOut;
  MemoryInterface memint(
    .cpuClock(clockSigCPU),
    .periphSelect(wPeriphSelectSignals[2]),
    .dIn(wDataToPeriphs[15:0]),
    .regSelect(wPeriphRegSelect[3:0]),
    .readEn(wPeriphRegReadEn),
    .writeEn(wPeriphRegWriteEn),
    .reset(res),
    .exec(wPeriphExec),
    .dataFromMem(wDataFromMem[15:0]),
    .debugRegSelect(snoopSelect[3:0]),
    .memStatus(1'b0),
    .dOut(wMemDataOut[15:0]),
    .dataToMem(wDataFromMemIntr[15:0]),
    .addrToMem(wAddrFromMemIntr[15:0]),
    .memReadEn(wMemRdFromIntr),
    .memWriteEn(wMemWrFromIntr),
    .debugOut(wMemIntrDebugOut[31:0])
  );
  
  // SD card interface (PID=3)
  // Debug sources:
  //   SnoopPeriph=2: Interface Registers
  //     Reg=0: R0 (Instruction)
  //     Reg=1: R1 (Status)
  //     Reg=2: R2 (Data-In)
  //     Reg=3: R3 (Data-Out)
  //     Reg=4: R4 (Address, 15-0)
  //   SnoopPeriph=3: {card signals[3:0], 0000, controller state[7:0]}
  wire [31:0] wDataFromSDInterface;
  wire [15:0] wSDIntrDebugOut;
  wire [15:0] wSDCtrlDebugOut;
  SDInterface sdint(
    .cpuClock(clockSigCPU),
    .periphSelect(wPeriphSelectSignals[3]),
    .regSelect(wPeriphRegSelect[3:0]),
    .readEn(wPeriphRegReadEn),
    .writeEn(wPeriphRegWriteEn),
    .reset(res),
    .dIn(wDataToPeriphs[31:0]),
    .exec(wPeriphExec),
    .miso(miso),
    .debugRegSelect(snoopSelect[4:0]),
    .serialClockOut(serialClock),
    .dOut(wDataFromSDInterface[31:0]),
    .chipSel(chipSelect),
    .mosi(mosi),
    .debugOut(wSDIntrDebugOut[15:0]),
    .debugControllerOut(wSDCtrlDebugOut[15:0])    
  );
  
  // PID=4 (UNUSED)
  
  // Monitor Interface (PID = 5)
  VGAInterface vgaIntr(
    .vgaClock(clk),
    .reset(res),
    .pixelData(wPixelData[15:0]),
    .vgaAddr(wVGAAddr[15:0]),
    .colorRed(vgaRed[3:0]),
    .colorGreen(vgaGreen[3:0]),
    .colorBlue(vgaBlue[3:0]),
    .hSync(hSync),
    .vSync(vSync)
  );
  
  // Keyboard Interface (PID = 6)
  // Debug Sources:
  //   SnoopPeriph=6:
  //     0: R0 (instruction (unused))
  //     1: R1 (status)
  //     2: R2 (keycode)
  wire [15:0] wKbdDataOut;
  wire [15:0] wKbdDebugOut;
  KeyboardInterface kbdIntr(
    .ctrlClock(clk),
    .cpuClock(clockSigCPU),
    .periphSelect(wPeriphSelectSignals[6]),
    .dIn(wDataToPeriphs[15:0]),
    .regSelect(wPeriphRegSelect[3:0]),
    .readEn(wPeriphRegReadEn),
    .writeEn(wPeriphRegWriteEn),
    .reset(res),
    .debugRegSelect(snoopSelect[2:0]),
    .ps2Clk(ps2Clk),
    .ps2Dat(ps2Dat),
    .dOut(wKbdDataOut[15:0]),
    .debugOut(wKbdDebugOut[15:0])
  );
  
//  assign ledsOut[15:0] = wKbdDataOut[15:0];               // TODO: Delete when done
  
  // Peripheral Data Bus
  Mux32B8to1 periphDataMux (
    .dIn0({16'h0000, wLEDIntrOut[15:0]}),
    .dIn1({16'h0000, wSegIntrOut[15:0]}),
    .dIn2({16'h0000, wMemDataOut[15:0]}),
    .dIn3(wDataFromSDInterface[31:0]),
    .dIn4(32'h00000000),
    .dIn5(32'h00000000),
    .dIn6({16'h0000, wKbdDataOut[15:0]}),
    .dIn7(32'h00000000),
    .sel(wPeriphSelect[2:0]),
    .dOut(wDataFromPeriphs[31:0])
  );
  
  // Snoop demultiplexing (for debugging)
  //   Format: 4xPart ID, 4x Reg Number
  //
  // Snoop IDs:
  //   0: CPU
  //   1: Memory Interface
  //   2: SD Interface
  //   3: SD Controller
  //   4: LED Interface
  //   5: VGA Interface (WIP)
  //   6: Keyboard Interface
  //   7: Seven Segment Display Interface
  Mux16B8to1 periphDbgOutSel (
    .dIn0(wCPUDebugOut[15:0]),
    .dIn1(wMemIntrDebugOut[15:0]),
    .dIn2(wSDIntrDebugOut[15:0]),
    .dIn3(wSDCtrlDebugOut[15:0]),
    .dIn4(wLEDDebugOut[15:0]),
    .dIn5(16'h00),
    .dIn6(wKbdDebugOut[15:0]),
    .dIn7(wSegDebugOut[15:0]),
    .sel(snoopSelect[6:4]),
    .dOut(snoopOut[15:0])
  );
  
  // Set the clock phase register to half the CPU clock's frequency
  //   (controls memory access in two stages: fetch instruction & data access
  always @ (posedge clockSigCPU) begin
    if(en) begin
      clockPhaseReg <= ~clockPhaseReg;
    end
  end
  
endmodule
