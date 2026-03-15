`timescale 1ns/1ps
//--------------------------------------------------------------------
// Project: APB-CSR-Generator
// Generator: Lenovo
// Date and time: 2026-03-15 17:49:44.133440
// Module: m_vlsit_crmcsr
// Function: Control & Status register via APB interface
// Page: VLSI Technology
//--------------------------------------------------------------------
module m_vlsit_crmcsr # (
  localparam PARA_CLOCK_EN_OFFSET = 16'h0000,
  localparam PARA_CLOCK_DIV_OFFSET = 16'h0004

)(
  input i_bus_clk,
  input i_bus_rstn,
  input [15:0] i_paddr,
  input i_protect_en,
  input i_slverr_en,
  input [2:0] i_pprot,
  input [31:0] i_pwdata,
  input i_pwrite,
  input i_penable,
  input i_psel,
  input [3:0] i_pstrb,
  output o_pslverr,
  output o_pready,
  output [31:0] o_prdata,
  output o_clock_en_en,
  output [7:0] o_clock_div_div
);
  //Logic signal declaration
  logic apb_setup;
  logic apb_protect;
  logic apb_slverr;
  logic apb_complete;
  logic apb_write;
  logic apb_read;
  logic [15:0] reg_address;
  logic [31:0] reg_pwdata;
  logic reg_slverr;
  logic apb_read_en;
  logic apb_write_en;
  logic [31:0] nxt_prdata;
  logic reg_pready;
  logic [31:0] reg_prdata;
  logic reg_apb_read_capture;
  logic reg_apb_write_capture;
  logic we_clock_en;
  logic reg_clock_en_en;
  logic nxt_clock_en_en;
  logic [31:0] clock_en_value;
  logic we_clock_div;
  logic [7:0] reg_clock_div_div;
  logic [7:0] nxt_clock_div_div;
  logic [31:0] clock_div_value;
  //end of logic signal declaration

  //APB general access phase assignment - START
  assign apb_setup = i_psel & ~i_penable;
  assign apb_protect = i_protect_en ? ~i_pprot[1] : 1'b1;
  assign apb_slverr = ~apb_protect      //error in protection
                      | (|i_paddr[1:0]) //error in address 
                      | (~&i_pstrb);    //error in pstrb signal
  assign apb_complete = apb_setup & (~apb_slverr);
  assign apb_write = i_pwrite & apb_complete;
  assign apb_read = ~i_pwrite & apb_complete; 
  
  //APB capture FF phase
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //address capture FF
    if(!i_bus_rstn) 
      reg_address <= '0;
    else if (apb_complete)
      reg_address <= i_paddr;
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //write data capture FF
    if(!i_bus_rstn) 
      reg_pwdata <= '0;
    else if (apb_write)
      reg_pwdata <= i_pwdata;
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //slverr output FF
    if(!i_bus_rstn) 
      reg_slverr <= '0;
    else if (apb_setup & i_slverr_en)
      reg_slverr <= apb_slverr;
  end
  assign o_pslverr = reg_slverr;
  //--------------------------------------------------------------------
  assign we_clock_en = apb_write_en & (reg_address == PARA_CLOCK_EN_OFFSET);
  assign we_clock_div = apb_write_en & (reg_address == PARA_CLOCK_DIV_OFFSET);


  //APB read/write register (appear when option Async is not selected) - START
  //--------------------------------------------------------------------
  //Reading phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_apb_read_capture <= '0;
    else
      reg_apb_read_capture <= apb_read;
  end
  assign apb_read_en = reg_apb_read_capture;

  //--------------------------------------------------------------------
  //Writing phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_apb_write_capture <= '0;
    else
      reg_apb_write_capture <= apb_write;
  end
  assign apb_write_en = reg_apb_write_capture;

  //--------------------------------------------------------------------
  //PREADY phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_pready <= '0;
    else
      reg_pready <= apb_write_en // reading complete
                | apb_read_en // writing complete
                | (apb_slverr & apb_setup & i_slverr_en);//slverr assert
  end
  assign o_pready = reg_pready;
  
  //--------------------------------------------------------------------

  //Assignment for next value of clock_en_en rw
  assign nxt_clock_en_en = (we_clock_en) ? reg_pwdata[0] : reg_clock_en_en;
  //FF for bit clock_en_en
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clock_en_en <= 1'h0;
    else
      reg_clock_en_en <= nxt_clock_en_en;
  end 
  assign o_clock_en_en = reg_clock_en_en;

  //--------------------------------------------------------------------
  //Combine the value of clock_en
  //--------------------------------------------------------------------
  always_comb begin
    clock_en_value[31:1] = '0;
    clock_en_value[0] = reg_clock_en_en;
  end  //Assignment for next value of clock_div_div rw
  assign nxt_clock_div_div = (we_clock_div) ? reg_pwdata[7:0] : reg_clock_div_div;
  //FF for bit clock_div_div
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clock_div_div <= 8'h0;
    else
      reg_clock_div_div <= nxt_clock_div_div;
  end 
  assign o_clock_div_div = reg_clock_div_div;

  //--------------------------------------------------------------------
  //Combine the value of clock_div
  //--------------------------------------------------------------------
  always_comb begin
    clock_div_value[31:8] = '0;
    clock_div_value[7:0] = reg_clock_div_div;
  end
  //--------------------------------------------------------------------
  //O_PRDATA phase
  //--------------------------------------------------------------------
  always_comb begin
    case (reg_address)
      PARA_CLOCK_EN_OFFSET: nxt_prdata = clock_en_value;
      PARA_CLOCK_DIV_OFFSET: nxt_prdata = clock_div_value;
      default nxt_prdata = '0;
    endcase
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_prdata <= '0;
    else if (apb_read_en)
      reg_prdata <= nxt_prdata;
  end
  assign o_prdata = reg_prdata;

endmodule: m_vlsit_crmcsr