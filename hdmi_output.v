/*
 *  vga_hardware -- Hardware for vga.
 *
 *  Please communicate with Junnan Li <lijunnan@nudt.edu.cn> when meeting any question.
 *  Copyright and related rights are licensed under the MIT license.
 *
 *  Data: 2021.11.20
 *  Description: teris_top. 
 */

`include "video_define.v"
module hdmi_output(
  input                 clk,           // pixel clock;
  input                 rst,           // reset signal high active;
  output  reg           hs_reg,        // horizontal synchronization;
  output  reg           vs_reg,        // vertical synchronization;
  output  wire          video_active,  // video valid;
  output  reg   [7:0]   rgb_r_reg,     // video red data;
  output  reg   [7:0]   rgb_g_reg,     // video green data;
  output  reg   [7:0]   rgb_b_reg,     // video blue data;
  output  reg   [11:0]  active_x,         
  output  reg   [11:0]  active_y,
  output  reg   [11:0]  h_cnt,         
  output  reg   [11:0]  v_cnt,
  input                 temp_bit        
);

//480x272 9Mhz
  parameter H_ACTIVE  = 16'd480; 
  parameter H_FP      = 16'd2;       
  parameter H_SYNC    = 16'd41;    
  parameter H_BP      = 16'd2;       
  parameter V_ACTIVE  = 16'd272; 
  parameter V_FP      = 16'd2;     
  parameter V_SYNC    = 16'd10;   
  parameter V_BP      = 16'd2;     
  parameter HS_POL    = 1'b0;
  parameter VS_POL    = 1'b0;

  parameter H_TOTAL   = H_ACTIVE + H_FP + H_SYNC + H_BP;//horizontal total time (pixels)
  parameter V_TOTAL   = V_ACTIVE + V_FP + V_SYNC + V_BP;//vertical total time (lines)

localparam  WHITE_R   = 8'hff,
            WHITE_G   = 8'hff,
            WHITE_B   = 8'hff,
            GRAY_R    = 8'd100,
            GRAY_G    = 8'd100,
            GRAY_B    = 8'd100,                                
            BLACK_R   = 8'h00,
            BLACK_G   = 8'h00,
            BLACK_B   = 8'h00;


reg h_active;   //* horizontal video active
reg v_active;   //* vertical video active

assign video_active = h_active & v_active;

always@(posedge clk or posedge rst) begin
  if(rst == 1'b1) begin
    //* initia h_cnt & v_cnt
    h_cnt         <= 12'd0;
    v_cnt         <= 12'd0;
  end
  else begin
    //* calc h_cnt, horizontal counter;
    if(h_cnt == H_TOTAL - 1) begin
      h_cnt       <= 12'd0;
    end
    else begin
      h_cnt       <= h_cnt + 12'd1;
    end

    //* calc v_cnt, vertical counter;
    if(h_cnt == H_FP  - 1) begin  //horizontal sync time
      if(v_cnt == V_TOTAL - 1) begin // maximum value
        v_cnt     <= 12'd0;
      end
      else begin
        v_cnt     <= v_cnt + 12'd1;
      end
    end
    else begin
      v_cnt       <= v_cnt;
    end
  end
end


always@(posedge clk or posedge rst) begin
  //* calc active_x;
  if(rst == 1'b1)
    active_x <= 12'd0;
  else if(h_cnt >= H_FP + H_SYNC + H_BP - 1)//horizontal video active
    active_x <= h_cnt - (H_FP[11:0] + H_SYNC[11:0] + H_BP[11:0] - 12'd9);
  else
    active_x <= active_x;

  //* calc active_y;
  if(rst == 1'b1)
    active_y <= 12'd0;
  else if(v_cnt >= V_FP + V_SYNC + V_BP - 1)//horizontal video active
    active_y <= v_cnt - (V_FP[11:0] + V_SYNC[11:0] + V_BP[11:0] - 12'd9);
  else
    active_y <= active_y;
end

//* output hs & vs;
always@(posedge clk or posedge rst) begin
  //* assign hs_reg, used for syn;
  if(rst == 1'b1)
    hs_reg <= 1'b0;
  else if(h_cnt == H_FP - 1)//horizontal sync begin
    hs_reg <= HS_POL;
  else if(h_cnt == H_FP + H_SYNC - 1)//horizontal sync end
    hs_reg <= ~hs_reg;
  else
    hs_reg <= hs_reg;

  //* assign vs_reg;
  if(rst == 1'b1)
    vs_reg <= 1'd0;
  else if((v_cnt == V_FP - 1) && (h_cnt == H_FP - 1))//vertical sync begin
    vs_reg <= HS_POL;
  else if((v_cnt == V_FP + V_SYNC - 1) && (h_cnt == H_FP - 1))//vertical sync end
    vs_reg <= ~vs_reg;  
  else
    vs_reg <= vs_reg;
end

//* output h_active & v_active;
always@(posedge clk or posedge rst) begin
  //* assign h_active (480), zone for showing;
  if(rst == 1'b1)
    h_active <= 1'b0;
  else if(h_cnt == H_FP + H_SYNC + H_BP - 1)//horizontal active begin
    h_active <= 1'b1;
  else if(h_cnt == H_TOTAL - 1)//horizontal active end
    h_active <= 1'b0;
  else
    h_active <= h_active;

  //* assign v_active (272);
  if(rst == 1'b1)
    v_active <= 1'd0;
  else if((v_cnt == V_FP + V_SYNC + V_BP - 1) && (h_cnt == H_FP - 1))//vertical active begin
    v_active <= 1'b1;
  else if((v_cnt == V_TOTAL - 1) && (h_cnt == H_FP - 1)) //vertical active end
    v_active <= 1'b0;   
  else
    v_active <= v_active;
end


always@(posedge clk or posedge rst) begin
  if(rst == 1'b1) begin
    rgb_r_reg         <= 8'h00;
    rgb_g_reg         <= 8'h00;
    rgb_b_reg         <= 8'h00;
  end
  else begin
    if(video_active) begin
      //* ture matrix (write if full, black if empty)
      if(active_x > 12'd15 && active_x < 12'd336 && 
        active_y > 12'd15 && active_y < 12'd176) begin
          if(temp_bit) begin
            if(active_x[3:0] == 4'd0 || active_x[3:0] == 4'd15 || 
              active_y[3:0] == 4'd0 || active_y[3:0] == 4'd15) begin
                rgb_r_reg   <= BLACK_R;
                rgb_g_reg   <= BLACK_G;
                rgb_b_reg   <= BLACK_B;
            end      
            else begin
                rgb_r_reg   <= WHITE_R;
                rgb_g_reg   <= WHITE_G;
                rgb_b_reg   <= WHITE_B;
            end
          end
          else begin
                rgb_r_reg   <= BLACK_R;
                rgb_g_reg   <= BLACK_G;
                rgb_b_reg   <= BLACK_B;
          end
      end
      //* edge of matrix (white);
      else if(active_x > 12'd12 && active_x < 12'd339 && 
        active_y > 12'd12 && active_y < 12'd179 &&
        (active_x == 12'd13 || active_x == 12'd14 ||
        active_x == 12'd337 || active_x == 12'd338 ||
        active_y == 12'd13 || active_y == 12'd14 ||
        active_y == 12'd177 || active_y == 12'd178)) begin
                rgb_r_reg   <= WHITE_R;
                rgb_g_reg   <= WHITE_G;
                rgb_b_reg   <= WHITE_B;
      end
      //* outside of the matrix (black);
      else begin
                rgb_r_reg   <= BLACK_R;
                rgb_g_reg   <= BLACK_G;
                rgb_b_reg   <= BLACK_B;
      end
    end
    //* don't care;
    else begin
                rgb_r_reg   <= BLACK_R;
                rgb_g_reg   <= BLACK_G;
                rgb_b_reg   <= BLACK_B;
    end
  end
end

endmodule 
