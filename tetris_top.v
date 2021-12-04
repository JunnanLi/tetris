/*
 *  vga_hardware -- Hardware for vga.
 *
 *  Please communicate with Junnan Li <lijunnan@nudt.edu.cn> when meeting any question.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2021.11.20
 *  Description: teris_top. 
 */

module tetris(
  input                 clk,           // pixel clock
  input                 rst,           // reset signal high active
  input                 left,
  input                 right,
  input                 rotate,
  input                 fall,
  output reg    [3:0]   led,
  output reg            hs,            // horizontal synchronization
  output reg            vs,            // vertical synchronization
  output reg            de,            // video valid
  output wire   [7:0]   rgb_r,         // video red data
  output wire   [7:0]   rgb_g,         // video green data
  output wire   [7:0]   rgb_b          // video blue data
);


wire  [11:0]  active_x, active_y; // video x,y position
wire  [11:0]  v_cnt, h_cnt;
wire          hs_syn, vs_syn;
wire          video_active; // video active(horizontal active and vertical active)
wire          temp_bit;

//* delay 1 clk;
always@(posedge clk or posedge rst) begin
  if(rst == 1'b1)
    begin
      hs <= 1'b0;
      vs <= 1'b0;
      de <= 1'b0;
    end
  else
    begin
      hs <= hs_syn;
      vs <= vs_syn;
      de <= video_active;
    end
end

//* output led, and obtain actions according to key input;
reg   [3:0] action;
reg   [3:0] temp_preAction_in;
wire  [3:0] temp_action_in;
assign      temp_action_in = {left, right, rotate, fall};
integer i;
always@(posedge clk or posedge rst) begin
  if(rst == 1'b1) begin
    led               <= 4'b0;
    action            <= 4'b0;
    temp_preAction_in <= 4'b0;
  end
  else begin
    temp_preAction_in <= temp_action_in;
    for(i=1; i<4; i=i+1) begin
      if(temp_action_in[i] == 1'b1 && temp_preAction_in[i] == 1'b0) begin
        led[i]        <= ~led[i];
        action[i]     <= 1'b1;
      end
      else begin
        action[i]     <= 1'b0;
      end
    end
    action[0]         <= ~fall;
    if(temp_action_in[0] == 1'b1 && temp_preAction_in[0] == 1'b0)
      led[0]          <= ~led[0];
  end
end

//* judege whether current 20*20 sub-block is empty? (temp_bit = '0'?) 
tetris_array tArray(
  .clk(clk),
  .rst(rst),
  .h_cnt(h_cnt),
  .v_cnt(v_cnt),
  .active_x(active_x),
  .active_y(active_y),
  .action(action),
  .temp_bit(temp_bit)
);

//* output rgb line by line;
hdmi_output hdmi_o(
  .clk(clk),
  .rst(rst),
  .hs_reg(hs_syn),
  .vs_reg(vs_syn),
  .video_active(video_active),
  .rgb_r_reg(rgb_r),
  .rgb_g_reg(rgb_g),
  .rgb_b_reg(rgb_b),
  .active_x(active_x),
  .active_y(active_y),
  .h_cnt(h_cnt),
  .v_cnt(v_cnt),
  .temp_bit(temp_bit) 
);

endmodule 
