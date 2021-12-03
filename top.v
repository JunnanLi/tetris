//////////////////////////////////////////////////////////////////////////////////
//   lcd color bar test                                                         //
//                                                                              //
//  Author: meisq                                                               //
//          msq@qq.com                                                          //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//     WEB: http://www.alinx.cn/                                                //
//     BBS: http://www.heijin.org/                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2017,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//2017/7/20                    1.0          Original
//*******************************************************************************/
module top(
input                       sys_clk,           //system clock 50Mhz on board
input                       rst_n,             //reset ,low active
input 						left,
input						right,
input						rotate,
input						fall,
output[3:0]					led,
output                      lcd_dclk,          //lcd clock
output                      lcd_hs,            //lcd horizontal synchronization
output                      lcd_vs,            //lcd vertical synchronization  
output                      lcd_de,            //lcd data valid
output[7:0]                 lcd_r,             //lcd red
output[7:0]                 lcd_g,             //lcd green
output[7:0]                 lcd_b              // lcd blue
);
wire                        video_clk;        //pixel clock
wire                        video_hs;         //horizontal synchronization
wire                        video_vs;         //vertical synchronization
wire                        video_de;         //video valid
wire[7:0]                   video_r;          //video red data
wire[7:0]                   video_g;          //video green data
wire[7:0]                   video_b;          //video blue data

assign lcd_hs = video_hs;
assign lcd_vs = video_vs;
assign lcd_de = video_de;
assign lcd_r  = video_r[7:0];
assign lcd_g  = video_g[7:0];
assign lcd_b  = video_b[7:0];
assign lcd_dclk = ~video_clk;              //to meet the timing requirements, the clock is inverting
/*************************************************************************
Generate the pixel clock  required for the video
****************************************************************************/
clk_wiz_0 video_pll_m0(
	// Clock out ports
	.clk_out1(video_clk),// output clk_out1
	// Status and control signals
	.reset(1'b0), 		// input reset
	.locked(),  		// output locked
	// Clock in ports
	.clk_in1(sys_clk)	// input clk_in1
);      


/*************************************************************************
Call color bar generation module
****************************************************************************/
// color_bar color_bar_m0(
// .clk                        (video_clk                ),
// .rst                        (~rst_n                   ),
// .hs                         (video_hs                 ),
// .vs                         (video_vs                 ),
// .de                         (video_de                 ),
// .rgb_r                      (video_r                  ),
// .rgb_g                      (video_g                  ),
// .rgb_b                      (video_b                  )
// );

// shift_color_bar shiftColorBar(
// .clk                        (video_clk                ),
// .rst                        (~rst_n                   ),
// .hs                         (video_hs                 ),
// .vs                         (video_vs                 ),
// .de                         (video_de                 ),
// .rgb_r                      (video_r                  ),
// .rgb_g                      (video_g                  ),
// .rgb_b                      (video_b                  )
// );

tetris tetris_inst(
.clk                        (video_clk                ),
.rst                        (~rst_n                   ),
.left                       (left                     ),
.right                      (right                    ),
.rotate                     (rotate                   ),
.fall                       (fall                     ),
.led 						(led                      ),
.hs                         (video_hs                 ),
.vs                         (video_vs                 ),
.de                         (video_de                 ),
.rgb_r                      (video_r                  ),
.rgb_g                      (video_g                  ),
.rgb_b                      (video_b                  )
);

endmodule