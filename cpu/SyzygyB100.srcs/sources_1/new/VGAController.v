`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/21/2017 02:18:42 AM
// Design Name: 
// Module Name: VGAController
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


module VGAController(
    input vgaClock,
    input reset,
    output reg [9:0] hCount = 10'b0000000000,
    output reg [9:0] vCount = 10'b0000000000,
    output reg hSync = 1'b0,
    output reg vSync = 1'b0,
    output reg disp
  );
  
  // Sync -> Back -> Video -> Front
  
  parameter LEN_HORIZ_DISP = 640;
  parameter LEN_HORIZ_BORDER_L = 48;
  parameter LEN_HORIZ_BORDER_R = 16;
  parameter LEN_HORIZ_RETRACE = 96;
  parameter HCOUNT_MAX = LEN_HORIZ_DISP + LEN_HORIZ_BORDER_L + LEN_HORIZ_BORDER_R + 
    LEN_HORIZ_RETRACE;
  parameter START_HORIZ_RETRACE = LEN_HORIZ_DISP + LEN_HORIZ_BORDER_R;
  parameter END_HORIZ_RETRACE = LEN_HORIZ_DISP + LEN_HORIZ_BORDER_R + LEN_HORIZ_RETRACE - 1;
  
  parameter LEN_VERT_DISP = 480;
  parameter LEN_VERT_BORDER_T = 12;     // Was 10
  parameter LEN_VERT_BORDER_B = 31;     // Was 33
  parameter LEN_VERT_RETRACE = 2;
  parameter VCOUNT_MAX = LEN_VERT_DISP + LEN_VERT_BORDER_T + LEN_VERT_BORDER_B +
    LEN_VERT_RETRACE;
  parameter START_VERT_RETRACE = LEN_VERT_DISP + LEN_VERT_BORDER_B;
  parameter END_VERT_RETRACE = LEN_VERT_DISP + LEN_VERT_BORDER_B + LEN_VERT_RETRACE - 1;    // Was Border_B
  
  reg [9:0] nextHCount = 10'b0000000000;
  reg [9:0] nextVCount = 10'b0000000000;
  wire nextHSync;
  wire nextVSync;
  wire nextDisp;
  
  // 25MHz clock divider
  wire wVGAClock;
  reg [1:0] vgaClkReg = 2'b00;
  assign wVGAClock = vgaClkReg[1];
  
  always @ (posedge vgaClock) begin
    if(reset == 1'b1) begin
      vgaClkReg = 0;
    end else begin
      vgaClkReg = vgaClkReg + 1;
    end
  end
  
  // Set line and row counts
  always @ (posedge wVGAClock) begin
    if(reset) begin
      hCount[9:0] = 0;
      vCount[9:0] = 0;
      hSync = 0;
      vSync = 0;
      disp = 0;
    end else begin
      hCount[9:0] = nextHCount[9:0];
      vCount[9:0] = nextVCount[9:0];
      hSync = nextHSync;
      vSync = nextVSync;
      disp = nextDisp;
    end
  end
  
  always @ (*) begin
    nextHCount[9:0] = (hCount[9:0] == HCOUNT_MAX) ? 0 : hCount[9:0] + 1;
    nextVCount[9:0] = (vCount[9:0] == VCOUNT_MAX) ? 0 : (
      (hCount[9:0] == HCOUNT_MAX) ? vCount[9:0] + 1 : vCount[9:0]
    );
  end
  
  assign nextHSync = (hCount[9:0] >= START_HORIZ_RETRACE && hCount[9:0] <= END_HORIZ_RETRACE);
  assign nextVSync = (vCount[9:0] >= START_VERT_RETRACE && vCount[9:0] <= END_VERT_RETRACE);
  assign nextDisp = hCount[9:0] < LEN_HORIZ_DISP && vCount[9:0] < LEN_VERT_DISP;
  
endmodule
