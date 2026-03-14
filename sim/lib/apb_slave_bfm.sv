`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Module: apb_slave_bfm
// Description:
//   APB3 slave BFM with internal word-addressed data memory.
//   Used for testing m_vlsi_csr module.
//------------------------------------------------------------------------------
module apb_slave_bfm #(
    parameter integer PARA_DMEM_DEPTH = 256,
    parameter integer PARA_APB_WAIT_STATES = 0
) (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic [15:0] i_paddr,
    input  logic [31:0] i_pwdata,
    output logic [31:0] o_prdata,
    input  logic        i_pwrite,
    input  logic        i_psel,
    input  logic        i_penable,
    output logic        o_pready
);

  localparam integer PARA_DMEM_ADDR_W = $clog2(PARA_DMEM_DEPTH);
  localparam logic [15:0] PARA_DMEM_DEPTH_U16 = PARA_DMEM_DEPTH[15:0];

  logic   [31:0] dmem [0:PARA_DMEM_DEPTH-1];

  integer        apb_wait_cnt;
  logic          apb_req_valid;
  logic          apb_req_write;
  logic   [15:0] apb_req_addr;
  logic   [31:0] apb_req_wdata;
  logic   [15:0] apb_req_word_addr;
  logic   [PARA_DMEM_ADDR_W-1:0] apb_req_word_idx;
  logic          apb_addr_in_range;
  logic   [31:0] apb_read_data;

  assign apb_req_word_addr = {14'b0, apb_req_addr[15:2]};
  assign apb_req_word_idx  = apb_req_addr[PARA_DMEM_ADDR_W+1:2];
  assign apb_addr_in_range = (apb_req_word_addr < PARA_DMEM_DEPTH_U16);
  assign apb_read_data     = apb_addr_in_range ? dmem[apb_req_word_idx] : 32'hdead_beef;

  // APB3 slave BFM:
  // - Captures requests during SETUP (PSEL=1, PENABLE=0)
  // - Completes requests in ACCESS (PSEL=1, PENABLE=1) after wait states
  // - Holds PREADY low while inserting wait states
  // - Returns 0xDEAD_BEEF on out-of-range reads
  always_ff @(posedge i_clk or negedge i_rst_n) begin : apb_slave_seq
    integer i;
    if (~i_rst_n) begin
      apb_req_valid <= 1'b0;
      apb_req_write <= 1'b0;
      apb_req_addr  <= 16'h0;
      apb_req_wdata <= 32'h0;
      apb_wait_cnt  <= 0;
      o_prdata      <= 32'h0;
      o_pready      <= 1'b0;
      for (i = 0; i < PARA_DMEM_DEPTH; i = i + 1) begin
        dmem[i] <= 32'h0;
      end
    end else begin
      o_pready <= 1'b0;

      // Setup phase capture
      if (i_psel && !i_penable) begin
        apb_req_valid <= 1'b1;
        apb_req_write <= i_pwrite;
        apb_req_addr  <= i_paddr;
        apb_req_wdata <= i_pwdata;
        apb_wait_cnt  <= PARA_APB_WAIT_STATES;
      end

      // Access phase response/handshake
      if (apb_req_valid && i_psel && i_penable) begin
        if (apb_wait_cnt > 0) begin
          apb_wait_cnt <= apb_wait_cnt - 1;
        end else begin
          o_pready <= 1'b1;
          o_prdata <= apb_read_data;

          if (apb_req_write && apb_addr_in_range) begin
            dmem[apb_req_word_idx] <= apb_req_wdata;
          end

          apb_req_valid <= 1'b0;
        end
      end
    end
  end

endmodule
