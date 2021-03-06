/*
 *  vga_hardware -- Hardware for vga.
 *
 *  Please communicate with Junnan Li <lijunnan@nudt.edu.cn> when meeting any question.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2021.11.20
 *  Description: top module. 
 */
module top(
  input                 sys_clk,    // system clock 50Mhz on board;
  input                 rst_n,      // reset ,low active;
  input                 left,       // key for left shift;
  input                 right,      // key for right shift;
  input                 rotate,     // key for rotating;
  input                 fall,       // key for falling down;
  output  wire   [3:0]  led,        // leds of FPGA for each key;
  output  wire          lcd_dclk,   // lcd clock;
  output  wire          lcd_hs,     // lcd horizontal synchronization;
  output  wire          lcd_vs,     // lcd vertical synchronization;  
  output  wire          lcd_de,     // lcd data valid;
  output  wire  [7:0]   lcd_r,      // lcd red;
  output  wire  [7:0]   lcd_g,      // lcd green;
  output  wire  [7:0]   lcd_b       // lcd blue;
);
wire          video_clk;            // pixel clock;
wire          video_hs;             // horizontal synchronization;
wire          video_vs;             // vertical synchronization;
wire          video_de;             // video valid;
wire  [7:0]   video_r;              // video red data;
wire  [7:0]   video_g;              // video green data;
wire  [7:0]   video_b;              // video blue data;

assign lcd_hs = video_hs;
assign lcd_vs = video_vs;
assign lcd_de = video_de;
assign lcd_r  = video_r[7:0];
assign lcd_g  = video_g[7:0];
assign lcd_b  = video_b[7:0];
assign lcd_dclk = ~video_clk;       // to meet the timing requirements;

//* Generate the pixel clock  required for the video
clk_wiz_0 video_pll_m0(
  //* Clock out ports
  .clk_out1(video_clk), // output clk_out1
  //* Status and control signals
  .reset(1'b0),         // input reset
  .locked(),            // output locked
  //* Clock in ports
  .clk_in1(sys_clk)     // input clk_in1
);      

//* tetris_inst
tetris tetris_inst(
  .clk      (video_clk  ),
  .rst      (~rst_n     ),
  .left     (left       ),
  .right    (right      ),
  .rotate   (rotate     ),
  .fall     (fall       ),
  .led      (led        ),
  .hs       (video_hs   ),
  .vs       (video_vs   ),
  .de       (video_de   ),
  .rgb_r    (video_r    ),
  .rgb_g    (video_g    ),
  .rgb_b    (video_b    )
);

endmodule
