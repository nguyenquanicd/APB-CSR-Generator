`timescale 1ns/1ps
//Author: Aurelian
//Project: CSR Generation tool
//Group: aQ-ent

module m_vlsi_synch #(
  parameter PARA_LEVELS = 2
)
(
  input i_clk,
  input i_rstn,
  input i_data_in,
  output o_data_out
);
  logic [PARA_LEVELS-1:0] reg_sync;
  
  generate //DFF Synchronizer behavior model, please comment out from them and replace with your model 
    if (PARA_LEVELS <= 1) begin : gen_single_level
      always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) 
          reg_sync[0] <= '0;
        else        
          reg_sync[0] <= i_data_in;
      end
    end 
    else begin : gen_multi_level
      always_ff @ (posedge i_clk, negedge i_rstn) begin
        if(!i_rstn) 
          reg_sync <= '0;
        else
          reg_sync <= {reg_sync[PARA_LEVELS-2:0],i_data_in};
      end
    end

  endgenerate
  assign o_data_out = reg_sync[PARA_LEVELS-1];

endmodule: m_vlsi_synch