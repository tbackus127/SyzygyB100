`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/15/2017 07:48:35 PM
// Design Name: 
// Module Name: KeyboardInterface
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


module KeyboardInterface(
    input ctrlClock,        // 100MHz board clock
    input cpuClock,         // CPU clock
    input periphSelect,
    input [15:0] dIn,
    input [3:0] regSelect,
    input readEn,
    input writeEn,
    input reset,
    input [2:0] debugRegSelect,
    input ps2Clk,
    input ps2Dat,
    output [15:0] dOut,
    output [15:0] debugOut
  );
  
  // Demultiplexer that chooses a peripheral register to read the value from, and sends its
  //  value to dOut, where it can be read by the CPU.
  wire [15:0] wReadEnSignals;
  Dmx4to16 readEnDmx(
    .sel(regSelect[3:0]),
    .en(periphSelect & readEn),
    .out(wReadEnSignals[15:0])
  );
  
  // Demultiplexer that chooses a peripheral register to write dIn's value to on the clock's
  //  falling edge.
  wire [15:0] wWriteEnSignals;
  Dmx4to16 writeEnDmx(
    .sel(regSelect[3:0]),
    .en(periphSelect & writeEn),
    .out(wWriteEnSignals[15:0])
  );
  
  // R0: Instruction (not used for this peripheral, but can be
  //       used for storage if needed).
  wire [15:0] wR0Out;
  wire [15:0] wR0DebugOut;
  SyzFETRegister2Out instrReg(
      .dIn(dIn[15:0]),
      .clockSig(cpuClock),
      .read(wReadEnSignals[0]),
      .write(wWriteEnSignals[0]),
      .reset(reset),
      .dOut(wR0Out[15:0]),
      .debugOut(wR0DebugOut[15:0])
    );
  
  // R1: Status (0x0000 = Ready, anything else = busy)
  reg status = 1'b0;
  
  // R2: Data Out (keycode)
  wire [15:0] wKeycodeIn;
  wire [15:0] wR2Out;
  wire [15:0] wR2DebugOut;
  wire wSetKeyReg;
  SyzFETRegister2Out keyReg(
    .dIn(wKeycodeIn[15:0]),
    .clockSig(ctrlClock),
    .read(1'b1),                  // Was wReadEnSignals[2]
    .write(1'b1),
    .reset(reset),
    .dOut(wR2Out[15:0]),
    .debugOut(wR2DebugOut[15:0])
  );
  
  // Converts wonky PS/2 scancodes to ones that make sense
  wire [15:0] wKeycodeOut;
  SyzKeycodeConverter conv(
    .convClk(ctrlClock),
    .keyIn(wKeycodeOut[15:0]),
    .keyOut(wKeycodeIn[15:0])
  );
  
  // Abstracts away the PS/2 signal receiver
  PS2Controller ps2Ctrl(
    .ps2CtrlClk(ctrlClock),
    .ps2clk(ps2Clk),
    .ps2data(ps2Dat),
    .keycode(wKeycodeOut[15:0]),
    .writeEn(wSetKeyReg),
    .debugOut()
  );
  
  // Output select
  Mux16B8to1 kbdOutMux(
    .dIn0(wR0Out[15:0]),
    .dIn1({15'b000000000000000, status}),
    .dIn2(wR2Out[15:0]),
    .dIn3(16'h0000),
    .dIn4(16'h0000),
    .dIn5(16'h0000),
    .dIn6(16'h0000),
    .dIn7(16'h0000),
    .sel(3'b010),
    .dOut(dOut[15:0])
  );
  
  // Debug output select
  Mux16B8to1 kbdDbgOutMux(
    .dIn0(wR0DebugOut[15:0]),
    .dIn1({15'b000000000000000, status}),
    .dIn2(wR2DebugOut[15:0]),
    .dIn3(16'h0000),
    .dIn4(16'h0000),
    .dIn5(16'h0000),
    .dIn6(16'h0000),
    .dIn7(16'h0000),
    .sel(debugRegSelect[2:0]),
    .dOut(debugOut[15:0])
  );
  
endmodule
