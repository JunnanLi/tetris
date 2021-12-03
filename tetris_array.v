/*
 *  vga_hardware -- Hardware for vga.
 *
 *  Please communicate with Junnan Li <lijunnan@nudt.edu.cn> when meeting any question.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2021.11.25
 *  Description: teris_array. 
 */

`include "video_define.v"
module tetris_array(
	input					clk,           //pixel clock
	input					rst,           //reset signal high active
	input			[11:0]	h_cnt,         // count of horizontal line
	input			[11:0]	v_cnt,         // count of vertical line
	input			[11:0]	active_x,
	input			[11:0]	active_y,
	input 			[3:0]	action,
	output	reg 			temp_bit
);
//video timing parameter definition

//480x272 9Mhz
`ifdef  VIDEO_480_272
	parameter H_ACTIVE = 16'd480; 
	parameter H_FP = 16'd2;       
	parameter H_SYNC = 16'd41;    
	parameter H_BP = 16'd2;       
	parameter V_ACTIVE = 16'd272; 
	parameter V_FP  = 16'd2;     
	parameter V_SYNC  = 16'd10;   
	parameter V_BP  = 16'd2;     
	parameter HS_POL = 1'b0;
	parameter VS_POL = 1'b0;
`endif

parameter H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;//horizontal total time (pixels)
parameter V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;//vertical total time (lines)

//* array_bitmap is the background array_bitmap, represents which point is white;
//* temp_bitmap represents whether current line is white, get from array_bitmap;
//* arrayBlock_bitmap is the block array_bitmap, represents which block point is white;
//* arrayBlock_rotate_bitmap is the block array_bitmap after rotating, represents which 
//*		block point is white;
//* temp_bit represents whether current point is white, get from temp_bitmap;
reg [19:0]	array_bitmap[10:0], temp_bitmap, arrayBlock_bitmap[9:0];
reg [19:0]	arrayBlock_rotate_bitmap[9:0];
// reg  		temp_bit;
//* temp_cloumn_bitmap has 1 bit to represent corresponding cloumn is full '1', need to clear;
//* flick_cloumn has 1 bit to corresponding cloumn is full '1' which is clearing;
wire [19:0]	temp_cloumn_bitmap; //* each cloumn has 1 bit, '1' is to clear;
reg [19:0]	flick_cloumn;
assign 		temp_cloumn_bitmap = {array_bitmap[0]&array_bitmap[1]&
									array_bitmap[2]&array_bitmap[3]&
									array_bitmap[4]&array_bitmap[5]&
									array_bitmap[6]&array_bitmap[7]&
									array_bitmap[8]&array_bitmap[9]}|flick_cloumn;
//* cnt_refresh is the count of refresh times (60Hz);
//* cnt_flick is the count of flick times, one flick equals 16 clks (60Hz);
reg [7:0]	cnt_refresh;
reg [1:0]	cnt_flick;		//* flick 3 times before clearing;
//* blockID is the ID of block type;
reg [2:0]	blockID; 	// 0 is oo 1 is   o 2 is o   3 is oo  4 is  oo  5 is  o   6 is oooo
						//      oo      ooo      ooo       oo      oo        ooo
//* tag of gen and combine:
//*		1) if tag_finish_gen != tag_finish_combine, combine background and block array;
//*		2) if tag_finish_gen == tag_finish_combine, gen new block array;
reg 		tag_finish_combine, tag_finish_gen;
reg [7:0]	temp_tag_finish_gen; //* delayed value of tag_finish_gen;
//* tag_equal_bitmap represents which background point meets block point;
reg [18:0]	tag_equal_bitmap;
//* check whether current needs to update (some point fall down to the buttom);
reg [1:0] 	cnt_check_line;
integer i;
always@(posedge clk or posedge rst) begin
	if(rst == 1'b1) begin
		//* initial bitmap;
		// for(i=0; i<10; i=i+1) begin
		// 	array_bitmap[i]	<= (20'hfff00 << i);
		// end
		// array_bitmap[10]	<= 20'b0;
		for(i=0; i<10; i=i+1) begin
			array_bitmap[i]	<= 20'h0;
		end
		temp_bitmap			<= 20'b0;
		flick_cloumn		<= 20'b0;
		temp_bit 			<= 1'b0;
		cnt_refresh			<= 8'b0;
		cnt_flick			<= 2'b0;
		tag_finish_combine	<= 1'b0;
		cnt_check_line		<= 2'b0;
	end
	else begin
		//* shift temp_bitmap
		if(h_cnt == 0) begin
			//* update temp_bitmap;
			case(active_y[7:4])
				4'd1:	temp_bitmap	<= array_bitmap[0]|arrayBlock_bitmap[0];
				4'd2:	temp_bitmap	<= array_bitmap[1]|arrayBlock_bitmap[1];
				4'd3:	temp_bitmap	<= array_bitmap[2]|arrayBlock_bitmap[2];
				4'd4:	temp_bitmap	<= array_bitmap[3]|arrayBlock_bitmap[3];
				4'd5:	temp_bitmap	<= array_bitmap[4]|arrayBlock_bitmap[4];
				4'd6:	temp_bitmap	<= array_bitmap[5]|arrayBlock_bitmap[5];
				4'd7:	temp_bitmap	<= array_bitmap[6]|arrayBlock_bitmap[6];
				4'd8:	temp_bitmap	<= array_bitmap[7]|arrayBlock_bitmap[7];
				4'd9:	temp_bitmap	<= array_bitmap[8]|arrayBlock_bitmap[8];
				4'd10:	temp_bitmap	<= array_bitmap[9]|arrayBlock_bitmap[9];
				default:temp_bitmap	<= array_bitmap[0]|arrayBlock_bitmap[0];
			endcase
		end
		else if(active_x[3:0] == 4'd15) begin
			temp_bitmap	<= {temp_bitmap[18:0],1'b0};
			temp_bit 	<= temp_bitmap[19];
		end

		//* update cnt_refresh;
		if((h_cnt == H_FP  - 1) && (v_cnt == V_TOTAL - 1)) begin
			cnt_refresh	<= cnt_refresh + 8'd1;
		end

		//* update array_bitmap;
		if((tag_finish_combine != temp_tag_finish_gen[7]) && (tag_equal_bitmap != 19'd0)) begin
			//* combine background with block;
			tag_finish_combine	<= ~tag_finish_combine;
			for(i=0; i<10; i=i+1)
				array_bitmap[i]	<= array_bitmap[i]|arrayBlock_bitmap[i];
			cnt_check_line		<= 2'b0;
		end
		else if(cnt_refresh[3:0] == 4'b0 && (v_cnt == V_TOTAL - 1) && (h_cnt == H_FP  - 1)) begin
			if(temp_cloumn_bitmap != 20'b0) begin
				//* update background by clearing completed line;
				cnt_flick		<= cnt_flick + 2'd1;
				(*full_case, parallel_case*)
				casez(temp_cloumn_bitmap)
					20'b1???_????_????_????_????: begin
						flick_cloumn			<= 20'h80000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][19]	<= ~array_bitmap[i][19];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i]	<= {array_bitmap[i][18:0],1'b0};
						end
					end
					20'b01??_????_????_????_????: begin
						flick_cloumn			<= 20'h40000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][18]	<= ~array_bitmap[i][18];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][18:0]	<= {array_bitmap[i][17:0],1'b0};
						end
					end
					20'b001?_????_????_????_????: begin
						flick_cloumn			<= 20'h20000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][17]	<= ~array_bitmap[i][17];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][17:0]	<= {array_bitmap[i][16:0],1'b0};
						end
					end
					20'b0001_????_????_????_????: begin
						flick_cloumn			<= 20'h10000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][16]	<= ~array_bitmap[i][16];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][16:0]	<= {array_bitmap[i][15:0],1'b0};
						end
					end
					20'b0000_1???_????_????_????: begin
						flick_cloumn			<= 20'h8000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][15]	<= ~array_bitmap[i][15];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][15:0]	<= {array_bitmap[i][14:0],1'b0};
						end
					end
					20'b0000_01??_????_????_????: begin
						flick_cloumn			<= 20'h4000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][14]	<= ~array_bitmap[i][14];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][14:0]	<= {array_bitmap[i][13:0],1'b0};
						end
					end
					20'b0000_001?_????_????_????: begin
						flick_cloumn			<= 20'h2000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][13]	<= ~array_bitmap[i][13];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][13:0]	<= {array_bitmap[i][12:0],1'b0};
						end
					end
					20'b0000_0001_????_????_????: begin
						flick_cloumn			<= 20'h1000;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][12]	<= ~array_bitmap[i][12];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][12:0]	<= {array_bitmap[i][11:0],1'b0};
						end
					end
					20'b0000_0000_1???_????_????: begin
						flick_cloumn			<= 20'h800;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][11]	<= ~array_bitmap[i][11];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][11:0]	<= {array_bitmap[i][10:0],1'b0};
						end
					end
					20'b0000_0000_01??_????_????: begin
						flick_cloumn			<= 20'h400;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][10]	<= ~array_bitmap[i][10];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][10:0]	<= {array_bitmap[i][9:0],1'b0};
						end
					end
					20'b0000_0000_001?_????_????: begin
						flick_cloumn			<= 20'h200;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][9]	<= ~array_bitmap[i][9];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][9:0]	<= {array_bitmap[i][8:0],1'b0};
						end
					end
					20'b0000_0000_0001_????_????: begin
						flick_cloumn			<= 20'h100;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][8]	<= ~array_bitmap[i][8];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][8:0]	<= {array_bitmap[i][7:0],1'b0};
						end
					end
					20'b0000_0000_0000_1???_????: begin
						flick_cloumn			<= 20'h80;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][7]	<= ~array_bitmap[i][7];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][7:0]	<= {array_bitmap[i][6:0],1'b0};
						end
					end
					20'b0000_0000_0000_01??_????: begin
						flick_cloumn			<= 20'h40;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][6]	<= ~array_bitmap[i][6];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][6:0]	<= {array_bitmap[i][5:0],1'b0};
						end
					end
					20'b0000_0000_0000_001?_????: begin
						flick_cloumn			<= 20'h20;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][5]	<= ~array_bitmap[i][5];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][5:0]	<= {array_bitmap[i][4:0],1'b0};
						end
					end
					20'b0000_0000_0000_0001_????: begin
						flick_cloumn			<= 20'h10;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][4]	<= ~array_bitmap[i][4];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][4:0]	<= {array_bitmap[i][3:0],1'b0};
						end
					end
					20'b0000_0000_0000_0000_1???: begin
						flick_cloumn			<= 20'h8;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][3]	<= ~array_bitmap[i][3];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][3:0]	<= {array_bitmap[i][2:0],1'b0};
						end
					end
					20'b0000_0000_0000_0000_01??: begin
						flick_cloumn			<= 20'h4;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][2]	<= ~array_bitmap[i][2];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][2:0]	<= {array_bitmap[i][1:0],1'b0};
						end
					end
					20'b0000_0000_0000_0000_001?: begin
						flick_cloumn			<= 20'h2;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][1]	<= ~array_bitmap[i][1];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][1:0]	<= {array_bitmap[i][0],1'b0};
						end
					end
					20'b0000_0000_0000_0000_0001: begin
						flick_cloumn			<= 20'h1;
						for(i=0; i<10; i=i+1)
							array_bitmap[i][0]	<= ~array_bitmap[i][0];
						if(cnt_flick == 2'd3) begin
							flick_cloumn		<= 20'b0;
							for(i=0; i<10; i=i+1)
								array_bitmap[i][0]	<= 1'b0;
						end
					end
				endcase
				cnt_check_line	<= 2'b0;
			end
			else begin
				cnt_check_line	<= cnt_check_line + 2'd1;
				//* just check 4 lines, only one point can fall down (down, right, left is empty);
				(*full_case, parallel_case*)
				case(cnt_check_line)
					2'd0: begin
						for(i=1; i<11; i=i+1) begin
							if(array_bitmap[i][19] == 1'b0 && array_bitmap[i][18] == 1'b1 &&
								array_bitmap[i-1][18] == 1'b0 && array_bitmap[i+1][18] == 1'b0)
								array_bitmap[i]			<= {array_bitmap[i][18:0],1'b0};
							else if(array_bitmap[i][18] == 1'b0 && array_bitmap[i][17] == 1'b1 &&
								array_bitmap[i-1][17] == 1'b0 && array_bitmap[i+1][17] == 1'b0)
								array_bitmap[i][18:0]	<= {array_bitmap[i][17:0],1'b0};
							else if(array_bitmap[i][17] == 1'b0 && array_bitmap[i][16] == 1'b1 &&
								array_bitmap[i-1][16] == 1'b0 && array_bitmap[i+1][16] == 1'b0)
								array_bitmap[i][17:0]	<= {array_bitmap[i][16:0],1'b0};
							else if(array_bitmap[i][16] == 1'b0 && array_bitmap[i][15] == 1'b1 &&
								array_bitmap[i-1][15] == 1'b0 && array_bitmap[i+1][15] == 1'b0)
								array_bitmap[i][16:0]	<= {array_bitmap[i][15:0],1'b0};
						end
						for(i=0; i<1; i=i+1) begin
							if(array_bitmap[i][19] == 1'b0 && array_bitmap[i][18] == 1'b1 &&
								array_bitmap[i+1][18] == 1'b0)
								array_bitmap[i]			<= {array_bitmap[i][18:0],1'b0};
							else if(array_bitmap[i][18] == 1'b0 && array_bitmap[i][17] == 1'b1 &&
								array_bitmap[i+1][17] == 1'b0)
								array_bitmap[i][18:0]	<= {array_bitmap[i][17:0],1'b0};
							else if(array_bitmap[i][17] == 1'b0 && array_bitmap[i][16] == 1'b1 &&
								array_bitmap[i+1][16] == 1'b0)
								array_bitmap[i][17:0]	<= {array_bitmap[i][16:0],1'b0};
							else if(array_bitmap[i][16] == 1'b0 && array_bitmap[i][15] == 1'b1 &&
								array_bitmap[i+1][15] == 1'b0)
								array_bitmap[i][16:0]	<= {array_bitmap[i][15:0],1'b0};
						end
					end
					2'd1: begin
						for(i=1; i<11; i=i+1) begin
							if(array_bitmap[i][15] == 1'b0 && array_bitmap[i][14] == 1'b1 &&
								array_bitmap[i-1][14] == 1'b0 && array_bitmap[i+1][14] == 1'b0)
								array_bitmap[i][15:0]	<= {array_bitmap[i][14:0],1'b0};
							else if(array_bitmap[i][14] == 1'b0 && array_bitmap[i][13] == 1'b1 &&
								array_bitmap[i-1][13] == 1'b0 && array_bitmap[i+1][13] == 1'b0)
								array_bitmap[i][14:0]	<= {array_bitmap[i][13:0],1'b0};
							else if(array_bitmap[i][13] == 1'b0 && array_bitmap[i][12] == 1'b1 &&
								array_bitmap[i-1][12] == 1'b0 && array_bitmap[i+1][12] == 1'b0)
								array_bitmap[i][13:0]	<= {array_bitmap[i][12:0],1'b0};
							else if(array_bitmap[i][12] == 1'b0 && array_bitmap[i][11] == 1'b1 &&
								array_bitmap[i-1][11] == 1'b0 && array_bitmap[i+1][11] == 1'b0)
								array_bitmap[i][12:0]	<= {array_bitmap[i][11:0],1'b0};
						end
						for(i=0; i<1; i=i+1) begin
							if(array_bitmap[i][15] == 1'b0 && array_bitmap[i][14] == 1'b1 &&
								array_bitmap[i+1][14] == 1'b0)
								array_bitmap[i][15:0]	<= {array_bitmap[i][14:0],1'b0};
							else if(array_bitmap[i][14] == 1'b0 && array_bitmap[i][13] == 1'b1 &&
								array_bitmap[i+1][13] == 1'b0)
								array_bitmap[i][14:0]	<= {array_bitmap[i][13:0],1'b0};
							else if(array_bitmap[i][13] == 1'b0 && array_bitmap[i][12] == 1'b1 &&
								array_bitmap[i+1][12] == 1'b0)
								array_bitmap[i][13:0]	<= {array_bitmap[i][12:0],1'b0};
							else if(array_bitmap[i][12] == 1'b0 && array_bitmap[i][11] == 1'b1 &&
								array_bitmap[i+1][11] == 1'b0)
								array_bitmap[i][12:0]	<= {array_bitmap[i][11:0],1'b0};
						end
					end
					2'd2: begin
						for(i=1; i<11; i=i+1) begin
							if(array_bitmap[i][11] == 1'b0 && array_bitmap[i][10] == 1'b1 &&
								array_bitmap[i-1][10] == 1'b0 && array_bitmap[i+1][10] == 1'b0)
								array_bitmap[i][11:0]	<= {array_bitmap[i][10:0],1'b0};
							else if(array_bitmap[i][10] == 1'b0 && array_bitmap[i][9] == 1'b1 &&
								array_bitmap[i-1][9] == 1'b0 && array_bitmap[i+1][9] == 1'b0)
								array_bitmap[i][10:0]	<= {array_bitmap[i][9:0],1'b0};
							else if(array_bitmap[i][9] == 1'b0 && array_bitmap[i][8] == 1'b1 &&
								array_bitmap[i-1][8] == 1'b0 && array_bitmap[i+1][8] == 1'b0)
								array_bitmap[i][9:0]	<= {array_bitmap[i][8:0],1'b0};
							else if(array_bitmap[i][8] == 1'b0 && array_bitmap[i][7] == 1'b1 &&
								array_bitmap[i-1][7] == 1'b0 && array_bitmap[i+1][7] == 1'b0)
								array_bitmap[i][8:0]	<= {array_bitmap[i][7:0],1'b0};
						end
						for(i=0; i<1; i=i+1) begin
							if(array_bitmap[i][11] == 1'b0 && array_bitmap[i][10] == 1'b1 &&
								array_bitmap[i+1][10] == 1'b0)
								array_bitmap[i][11:0]	<= {array_bitmap[i][10:0],1'b0};
							else if(array_bitmap[i][10] == 1'b0 && array_bitmap[i][9] == 1'b1 &&
								array_bitmap[i+1][9] == 1'b0)
								array_bitmap[i][10:0]	<= {array_bitmap[i][9:0],1'b0};
							else if(array_bitmap[i][9] == 1'b0 && array_bitmap[i][8] == 1'b1 &&
								array_bitmap[i+1][8] == 1'b0)
								array_bitmap[i][9:0]	<= {array_bitmap[i][8:0],1'b0};
							else if(array_bitmap[i][8] == 1'b0 && array_bitmap[i][7] == 1'b1 &&
								array_bitmap[i+1][7] == 1'b0)
								array_bitmap[i][8:0]	<= {array_bitmap[i][7:0],1'b0};
						end
					end
					2'd3: begin
						for(i=1; i<11; i=i+1) begin
							if(array_bitmap[i][7] == 1'b0 && array_bitmap[i][6] == 1'b1 &&
								array_bitmap[i-1][6] == 1'b0 && array_bitmap[i+1][6] == 1'b0)
								array_bitmap[i][7:0]	<= {array_bitmap[i][6:0],1'b0};
							else if(array_bitmap[i][6] == 1'b0 && array_bitmap[i][5] == 1'b1 &&
								array_bitmap[i-1][5] == 1'b0 && array_bitmap[i+1][5] == 1'b0)
								array_bitmap[i][6:0]	<= {array_bitmap[i][5:0],1'b0};
							else if(array_bitmap[i][5] == 1'b0 && array_bitmap[i][4] == 1'b1 &&
								array_bitmap[i-1][4] == 1'b0 && array_bitmap[i+1][4] == 1'b0)
								array_bitmap[i][5:0]	<= {array_bitmap[i][4:0],1'b0};
							else if(array_bitmap[i][4] == 1'b0 && array_bitmap[i][3] == 1'b1 &&
								array_bitmap[i-1][3] == 1'b0 && array_bitmap[i+1][3] == 1'b0)
								array_bitmap[i][4:0]	<= {array_bitmap[i][3:0],1'b0};
						end
						for(i=0; i<1; i=i+1) begin
							if(array_bitmap[i][7] == 1'b0 && array_bitmap[i][6] == 1'b1 &&
								array_bitmap[i+1][6] == 1'b0)
								array_bitmap[i][7:0]	<= {array_bitmap[i][6:0],1'b0};
							else if(array_bitmap[i][6] == 1'b0 && array_bitmap[i][5] == 1'b1 &&
								array_bitmap[i+1][5] == 1'b0)
								array_bitmap[i][6:0]	<= {array_bitmap[i][5:0],1'b0};
							else if(array_bitmap[i][5] == 1'b0 && array_bitmap[i][4] == 1'b1 &&
								array_bitmap[i+1][4] == 1'b0)
								array_bitmap[i][5:0]	<= {array_bitmap[i][4:0],1'b0};
							else if(array_bitmap[i][4] == 1'b0 && array_bitmap[i][3] == 1'b1 &&
								array_bitmap[i+1][3] == 1'b0)
								array_bitmap[i][4:0]	<= {array_bitmap[i][3:0],1'b0};
						end
					end
				endcase
			end
		end
	end
end

//* gen and shift block;
//* tag_rotate[5:0], while [1] != [0], means need to rotate (chose type);
//*		while [2] != [1], means need to rotate (left shift);
//*		while [3] != [2], means need to rotate (right shift);
//*		while [4] != [3], means need to rotate (down shift);
//*		while [5] != [4], means need to replace current arrayBlock_bitmap;
reg [5:0]	tag_rotate;
reg [3:0]	cnt_rotate, cnt_left, cnt_right, cnt_down;
always @(posedge clk or posedge rst) begin
	if(rst == 1'b1) begin
		blockID								<= 3'b0;
		tag_finish_gen						<= 1'b0;
		temp_tag_finish_gen					<= 8'b0;
		for(i=0; i<10; i=i+1) begin
			arrayBlock_bitmap[i]			<= 20'b0;
			arrayBlock_rotate_bitmap[i]		<= 20'b0;
		end
		tag_rotate							<= 6'b0;
		{cnt_rotate, cnt_left, cnt_right, cnt_down}	<= 16'b0;
	end
	else begin
		//* gen new block;
		if(tag_equal_bitmap == 0 && tag_rotate != 6'h0 && tag_rotate != 6'h3f) begin
			if(tag_rotate[1] != tag_rotate[0]) begin
				//* chose one type
				for(i=0; i<10; i=i+1)
					arrayBlock_rotate_bitmap[i]		<= 20'b0;
				case({blockID,cnt_rotate[1:0]})
					{3'd2,2'd0}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h2;	//*   o
						arrayBlock_rotate_bitmap[5]	<= 20'h2;	//* ooo
						arrayBlock_rotate_bitmap[6]	<= 20'h3;
					end
					{3'd2,2'd1}: begin 				//*				oo
						arrayBlock_rotate_bitmap[4]	<= 20'h1;	//*  o
						arrayBlock_rotate_bitmap[5]	<= 20'h7;	//*  o
					end
					{3'd2,2'd2}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h3;	//* o 
						arrayBlock_rotate_bitmap[5]	<= 20'h1;	//* ooo
						arrayBlock_rotate_bitmap[6]	<= 20'h1;
					end
					{3'd2,2'd3}: begin 			//*				  	  o
						arrayBlock_rotate_bitmap[5]	<= 20'h7;	//*   o
						arrayBlock_rotate_bitmap[6]	<= 20'h4;	//*  oo
					end

					{3'd3,2'd0}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h3;	//* o
						arrayBlock_rotate_bitmap[5]	<= 20'h2;	//* ooo
						arrayBlock_rotate_bitmap[6]	<= 20'h2;
					end
					{3'd3,2'd1}: begin 				//*				 o
						arrayBlock_rotate_bitmap[4]	<= 20'h4;	//*  o
						arrayBlock_rotate_bitmap[5]	<= 20'h7;	//* oo
					end
					{3'd3,2'd2}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h1;	//* ooo
						arrayBlock_rotate_bitmap[5]	<= 20'h1;	//*   o
						arrayBlock_rotate_bitmap[6]	<= 20'h3;
					end
					{3'd3,2'd3}: begin 				//*				 oo
						arrayBlock_rotate_bitmap[5]	<= 20'h7;	//*  o
						arrayBlock_rotate_bitmap[6]	<= 20'h1;	//*  o
					end

					{3'd4,2'd0}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h1;	//* oo
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//*  oo
						arrayBlock_rotate_bitmap[6]	<= 20'h2;
					end
					{3'd4,2'd1}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h6;	//*  o
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//* oo
						// arrayBlock_bitmap[6]	<= 20'h3;		//* o
					end
					{3'd4,2'd2}: begin 			
						arrayBlock_rotate_bitmap[4]	<= 20'h1;	//* oo
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//*  oo
						arrayBlock_rotate_bitmap[6]	<= 20'h2;
					end
					{3'd4,2'd3}: begin 
						arrayBlock_rotate_bitmap[5]	<= 20'h6;	//*  o
						arrayBlock_rotate_bitmap[6]	<= 20'h3;	//* oo
						// arrayBlock_bitmap[6]	<= 20'h3;		//* o
					end

					{3'd5,2'd0}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h2;	//*  oo
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//* oo
						arrayBlock_rotate_bitmap[6]	<= 20'h1;
					end
					{3'd5,2'd1}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h3;	//* o
						arrayBlock_rotate_bitmap[5]	<= 20'h6;	//* oo
						// arrayBlock_bitmap[6]	<= 20'h3;		//*  o
					end
					{3'd5,2'd2}: begin 			
						arrayBlock_rotate_bitmap[4]	<= 20'h2;	//*  oo
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//* oo
						arrayBlock_rotate_bitmap[6]	<= 20'h1;
					end
					{3'd5,2'd3}: begin 
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//* o
						arrayBlock_rotate_bitmap[6]	<= 20'h6;	//* oo
						// arrayBlock_bitmap[6]	<= 20'h3;		//*  o
					end

					{3'd6,2'd0}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h2;	//*  o
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//* ooo
						arrayBlock_rotate_bitmap[6]	<= 20'h2;
					end
					{3'd6,2'd1}: begin
						arrayBlock_rotate_bitmap[4]	<= 20'h2;	//*  o
						arrayBlock_rotate_bitmap[5]	<= 20'h7;	//* oo
						// arrayBlock_bitmap[6]	<= 20'h3;		//*  o
					end
					{3'd6,2'd2}: begin 			
						arrayBlock_rotate_bitmap[4]	<= 20'h1;	//* ooo
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//*  o
						arrayBlock_rotate_bitmap[6]	<= 20'h1;
					end
					{3'd6,2'd3}: begin 
						arrayBlock_rotate_bitmap[5]	<= 20'h7;	//*  o
						arrayBlock_rotate_bitmap[6]	<= 20'h2;	//*  oo
						// arrayBlock_bitmap[6]	<= 20'h3;		//*  o
					end

					{3'd0,2'd0}: begin
						arrayBlock_rotate_bitmap[3]	<= 20'h2;	//*  
						arrayBlock_rotate_bitmap[4]	<= 20'h2;	//* oooo
						arrayBlock_rotate_bitmap[5]	<= 20'h2;
						arrayBlock_rotate_bitmap[6]	<= 20'h2;
					end
					{3'd0,2'd1}: begin 							//*  o
						arrayBlock_rotate_bitmap[5]	<= 20'hf;	//*  o
						// arrayBlock_bitmap[5]	<= 20'h7;		//*  o
						// arrayBlock_bitmap[6]	<= 20'h3;		//*  o
					end
					{3'd0,2'd2}: begin 	
						arrayBlock_rotate_bitmap[3]	<= 20'h2;	//*  
						arrayBlock_rotate_bitmap[4]	<= 20'h2;	//* oooo
						arrayBlock_rotate_bitmap[5]	<= 20'h2;
						arrayBlock_rotate_bitmap[6]	<= 20'h2;
					end
					{3'd0,2'd3}: begin 							//*  o
						arrayBlock_rotate_bitmap[5]	<= 20'hf;	//*  o
						// arrayBlock_bitmap[5]	<= 20'h7;		//*  o
						// arrayBlock_bitmap[6]	<= 20'h3;		//*  o
					end

					default: begin 				
						arrayBlock_rotate_bitmap[4]	<= 20'h3;	//*  oo
						arrayBlock_rotate_bitmap[5]	<= 20'h3;	//*  oo
					end
				endcase
				tag_rotate[1]	<= ~tag_rotate[1];
			end
			else if(tag_rotate[2] != tag_rotate[1]) begin
				//* left shift
				case(cnt_left[2:0])
					3'd1: begin
						for(i=0; i<9; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= arrayBlock_rotate_bitmap[i+1];
						for(i=9; i<10; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd2: begin
						for(i=0; i<8; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= arrayBlock_rotate_bitmap[i+2];
						for(i=8; i<10; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd3: begin
						for(i=0; i<7; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= arrayBlock_rotate_bitmap[i+3];
						for(i=7; i<10; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd4: begin
						for(i=0; i<6; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= arrayBlock_rotate_bitmap[i+4];
						for(i=6; i<10; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd5: begin
						for(i=0; i<5; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= arrayBlock_rotate_bitmap[i+5];
						for(i=5; i<10; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					default: begin end
				endcase
				tag_rotate[2]	<= ~tag_rotate[2];
			end
			else if(tag_rotate[3] != tag_rotate[2]) begin
				//* right shift
				case(cnt_right[2:0])
					3'd1: begin
						for(i=0; i<9; i=i+1)
							arrayBlock_rotate_bitmap[i+1]	<= arrayBlock_rotate_bitmap[i];
						for(i=0; i<1; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd2: begin
						for(i=0; i<8; i=i+1)
							arrayBlock_rotate_bitmap[i+2]	<= arrayBlock_rotate_bitmap[i];
						for(i=0; i<2; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd3: begin
						for(i=0; i<7; i=i+1)
							arrayBlock_rotate_bitmap[i+3]	<= arrayBlock_rotate_bitmap[i];
						for(i=0; i<3; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd4: begin
						for(i=0; i<6; i=i+1)
							arrayBlock_rotate_bitmap[i+4]	<= arrayBlock_rotate_bitmap[i];
						for(i=0; i<4; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					3'd5: begin
						for(i=0; i<5; i=i+1)
							arrayBlock_rotate_bitmap[i+5]	<= arrayBlock_rotate_bitmap[i];
						for(i=0; i<5; i=i+1)
							arrayBlock_rotate_bitmap[i]	<= 20'b0;
					end
					default: begin end
				endcase
				tag_rotate[3]	<= ~tag_rotate[3];
			end
			else if(tag_rotate[4] != tag_rotate[3]) begin
				//* down shift
				for(i=0; i<10; i=i+1)
					arrayBlock_rotate_bitmap[i]	<= arrayBlock_rotate_bitmap[i] << cnt_down[3:0];
				tag_rotate[4]	<= ~tag_rotate[4];
			end
			else if(tag_rotate[5] != tag_rotate[4]) begin
				for(i=0; i<10; i=i+1)
					arrayBlock_bitmap[i]	<= arrayBlock_rotate_bitmap[i];
				tag_rotate[5]	<= ~tag_rotate[5];
			end
		end
		else if(action != 4'b0 && tag_equal_bitmap == 0) begin
			//* left
			if(action[3] == 1'b1) begin
				//* shift block;
				for(i=0; i<9; i=i+1)
					arrayBlock_bitmap[i]	<= arrayBlock_bitmap[i+1];
				arrayBlock_bitmap[9]		<= arrayBlock_bitmap[0];
				if(cnt_right != 4'b0)
					cnt_right				<= cnt_right - 4'd1;
				else
					cnt_left				<= cnt_left + 4'd1;
			end
			//* right
			else if(action[2] == 1'b1) begin
				for(i=1; i<10; i=i+1)
					arrayBlock_bitmap[i]	<= arrayBlock_bitmap[i-1];
				arrayBlock_bitmap[0]		<= arrayBlock_bitmap[9];
				if(cnt_left != 4'b0)
					cnt_left				<= cnt_left - 4'd1;
				else
					cnt_right				<= cnt_right + 4'd1;
			end
			//* rotate
			else if(action[1] == 1'b1) begin
				//* TODO...
				if(blockID != 3'd1)
					tag_rotate[0]			<= ~tag_rotate[0];
				cnt_rotate					<= cnt_rotate + 4'd1;
			end
			//* fall down;
			else if(action[0] == 1'b1 && cnt_refresh[1:0] == 2'b0 &&
			(h_cnt == H_FP  - 1) && (v_cnt == V_TOTAL - 1)) begin
				for(i=0; i<10; i=i+1)
					arrayBlock_bitmap[i]	<= {arrayBlock_bitmap[i][18:0],1'b0};
				cnt_down					<= cnt_down + 4'd1;
			end 
		end
		else if(cnt_refresh[4:0] == 5'b0 && (h_cnt == H_FP  - 1) && (v_cnt == V_TOTAL - 1)) begin
			if(tag_finish_gen == tag_finish_combine) begin
				tag_finish_gen				<= ~tag_finish_gen;
				blockID						<= (blockID == 3'd6)? 3'b0: blockID + 3'd1;
				for(i=0; i<10; i=i+1)
					arrayBlock_bitmap[i]	<= 20'b0;
				case(blockID)
					3'd0: begin
						arrayBlock_bitmap[4]	<= 20'h3;
						arrayBlock_bitmap[5]	<= 20'h3;
					end
					3'd1: begin
						arrayBlock_bitmap[4]	<= 20'h2;
						arrayBlock_bitmap[5]	<= 20'h2;
						arrayBlock_bitmap[6]	<= 20'h3;
					end
					3'd2: begin
						arrayBlock_bitmap[4]	<= 20'h3;
						arrayBlock_bitmap[5]	<= 20'h2;
						arrayBlock_bitmap[6]	<= 20'h2;
					end
					3'd3: begin
						arrayBlock_bitmap[4]	<= 20'h1;
						arrayBlock_bitmap[5]	<= 20'h3;
						arrayBlock_bitmap[6]	<= 20'h2;
					end
					3'd4: begin
						arrayBlock_bitmap[4]	<= 20'h2;
						arrayBlock_bitmap[5]	<= 20'h3;
						arrayBlock_bitmap[6]	<= 20'h1;
					end
					3'd5: begin
						arrayBlock_bitmap[4]	<= 20'h2;
						arrayBlock_bitmap[5]	<= 20'h3;
						arrayBlock_bitmap[6]	<= 20'h2;
					end
					3'd6: begin
						arrayBlock_bitmap[3]	<= 20'h1;
						arrayBlock_bitmap[4]	<= 20'h1;
						arrayBlock_bitmap[5]	<= 20'h1;
						arrayBlock_bitmap[6]	<= 20'h1;
					end
					default: begin
						arrayBlock_bitmap[4]	<= 20'h3;
						arrayBlock_bitmap[5]	<= 20'h3;
					end
				endcase
				{cnt_rotate, cnt_left, cnt_right, cnt_down}	<= 16'b0;
			end
			else begin
				//* shift block;
				for(i=0; i<10; i=i+1)
					arrayBlock_bitmap[i]	<= {arrayBlock_bitmap[i][18:0],1'b0};
				cnt_down					<= cnt_down + 4'd1;
			end
		end
		temp_tag_finish_gen					<= {temp_tag_finish_gen[6:0],tag_finish_gen};
	end
end

//* check whether shifting has finished;
reg [9:0]	array_cloumn_bitmap[19:0], arrayBlock_cloumn_bitmap[19:0];
always @(posedge clk or posedge rst) begin
	if(rst == 1'b1) begin
		for(i=0; i<20; i=i+1) begin
			array_cloumn_bitmap[i]	<= 10'b0;
			arrayBlock_cloumn_bitmap[i]	<= 10'b0;
		end
		tag_equal_bitmap			<= 19'b0;
	end
	else begin
		//* get cloumn value;
		for(i=0; i<20; i=i+1) begin
			arrayBlock_cloumn_bitmap[i]	<= {arrayBlock_bitmap[0][19-i],arrayBlock_bitmap[1][19-i],
										arrayBlock_bitmap[2][19-i],arrayBlock_bitmap[3][19-i],
										arrayBlock_bitmap[4][19-i],arrayBlock_bitmap[5][19-i],
										arrayBlock_bitmap[6][19-i],arrayBlock_bitmap[7][19-i],
										arrayBlock_bitmap[8][19-i],arrayBlock_bitmap[9][19-i]};
			array_cloumn_bitmap[i]	<={array_bitmap[0][19-i],array_bitmap[1][19-i],
										array_bitmap[2][19-i],array_bitmap[3][19-i],
										array_bitmap[4][19-i],array_bitmap[5][19-i],
										array_bitmap[6][19-i],array_bitmap[7][19-i],
										array_bitmap[8][19-i],array_bitmap[9][19-i]};
		end
		// if(cnt_refresh[3:0] == 4'd8) begin
			for(i=0;i<19;i=i+1) begin
				if(((array_cloumn_bitmap[i] & arrayBlock_cloumn_bitmap[i+1]) != 10'd0) ||
					arrayBlock_cloumn_bitmap[0] != 10'b0)
						tag_equal_bitmap[i]		<= 1'b1;
				else	tag_equal_bitmap[i]		<= 1'b0;
			end
		// end
	end
end



endmodule 