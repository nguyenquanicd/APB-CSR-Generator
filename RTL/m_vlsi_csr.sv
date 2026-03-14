`timescale 1ns/1ps
//--------------------------------------------------------------------
//Product of: VLSI Technology
//Project: The UVM environemnt for UART (Universal Asynchronous Receiver Transmitter)
//Generator: ltthinh
//Date and time: 2026-03-14 17:38:07.453065
//Module:  m_vlsi_csr
//Function: Control & Status register
//Page:    VLSI Technology
//---------------------------------------
module m_vlsi_csr # (
  localparam PARA_ABC_OFFSET = 16'h0,
  localparam PARA_DEF_OFFSET = 16'h4

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
  input i_abc_start0,
  output o_abc_start1,
  output o_abc_start2,
  input i_hw_wdata_abc_start2,
  input i_hw_we_abc_start2,
  output [1:0] o_abc_start3,
  output [1:0] o_abc_start4,
  input [1:0] i_hw_wdata_abc_start4,
  input i_hw_we_abc_start4,
  output o_def_start0,
  output o_def_start1,
  input i_hw_wdata_def_start1,
  input i_hw_we_def_start1,
  output o_def_start2,
  input i_hw_wdata_def_start2,
  input i_hw_we_def_start2,
  output [1:0] o_def_start3,
  input [1:0] i_hw_wdata_def_start3,
  input i_hw_we_def_start3,
  output [1:0] o_def_start4,
  input [1:0] i_hw_wdata_def_start4,
  input i_hw_we_def_start4
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
  logic we_abc;
  logic reg_abc_start1;
  logic nxt_abc_start1;
  logic reg_abc_start2;
  logic nxt_abc_start2;
  logic [1:0] reg_abc_start3;
  logic [1:0] nxt_abc_start3;
  logic [1:0] reg_abc_start4;
  logic [1:0] nxt_abc_start4;
  logic [31:0] abc_value;
  logic we_def;
  logic reg_def_start0;
  logic nxt_def_start0;
  logic reg_def_start1;
  logic nxt_def_start1;
  logic reg_def_start2;
  logic nxt_def_start2;
  logic [1:0] reg_def_start3;
  logic [1:0] nxt_def_start3;
  logic [1:0] reg_def_start4;
  logic [1:0] nxt_def_start4;
  logic [31:0] def_value;
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
  assign we_abc = apb_write_en & (reg_address == PARA_ABC_OFFSET);
  assign we_def = apb_write_en & (reg_address == PARA_DEF_OFFSET);


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

  //Assignment for next value of abc_start1 rw
  assign nxt_abc_start1 = (we_abc) ? reg_pwdata[30] : reg_abc_start1;
  //FF for bit abc_start1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_abc_start1 <= 1'h0;
    else
      reg_abc_start1 <= nxt_abc_start1;
  end 
  assign o_abc_start1 = reg_abc_start1;
  //Assignment for next value of abc_start2 rwi
  assign nxt_abc_start2 = (we_abc) ? reg_pwdata[29]
                        : (i_hw_we_abc_start2) ? i_hw_wdata_abc_start2
                        : reg_abc_start2;
  //FF for bit abc_start2
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_abc_start2 <= 1'h0;
    else
      reg_abc_start2 <= nxt_abc_start2;
  end 
  assign o_abc_start2 = reg_abc_start2;
  //Assignment for next value of abc_start3 rw
  assign nxt_abc_start3 = (we_abc) ? reg_pwdata[28:27] : reg_abc_start3;
  //FF for bit abc_start3
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_abc_start3 <= 2'h0;
    else
      reg_abc_start3 <= nxt_abc_start3;
  end 
  assign o_abc_start3 = reg_abc_start3;
  //Assignment for next value of abc_start4 rwi
  assign nxt_abc_start4 = (we_abc) ? reg_pwdata[26:25]
                        : (i_hw_we_abc_start4) ? i_hw_wdata_abc_start4
                        : reg_abc_start4;
  //FF for bit abc_start4
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_abc_start4 <= 2'h0;
    else
      reg_abc_start4 <= nxt_abc_start4;
  end 
  assign o_abc_start4 = reg_abc_start4;

  //--------------------------------------------------------------------
  //Combine the value of abc
  //--------------------------------------------------------------------
  always_comb begin
    abc_value[31] = i_abc_start0;
    abc_value[30] = reg_abc_start1;
    abc_value[29] = reg_abc_start2;
    abc_value[28:27] = reg_abc_start3;
    abc_value[26:25] = reg_abc_start4;
    abc_value[24:0] = '0;
  end  //Assignment for next value of def_start0 rw
  assign nxt_def_start0 = (we_def) ? reg_pwdata[31] : reg_def_start0;
  //FF for bit def_start0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_def_start0 <= 1'h0;
    else
      reg_def_start0 <= nxt_def_start0;
  end 
  assign o_def_start0 = reg_def_start0;
  //Assignment for next value of def_start1 rwi
  assign nxt_def_start1 = (we_def) ? reg_pwdata[30]
                        : (i_hw_we_def_start1) ? i_hw_wdata_def_start1
                        : reg_def_start1;
  //FF for bit def_start1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_def_start1 <= 1'h0;
    else
      reg_def_start1 <= nxt_def_start1;
  end 
  assign o_def_start1 = reg_def_start1;
  //Assignment for next value of def_start2 w1c
  assign nxt_def_start2 = (we_def) ? (~reg_pwdata[29] & reg_def_start2)
                        : (i_hw_we_def_start2) ? i_hw_wdata_def_start2
                        : reg_def_start2;
  //FF for bit def_start2
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_def_start2 <= 1'h0;
    else
      reg_def_start2 <= nxt_def_start2;
  end 
  assign o_def_start2 = reg_def_start2;
  //Assignment for next value of def_start3 w1c
  assign nxt_def_start3 = (we_def) ? (~reg_pwdata[28:27] & reg_def_start3)
                        : (i_hw_we_def_start3) ? i_hw_wdata_def_start3
                        : reg_def_start3;
  //FF for bit def_start3
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_def_start3 <= 2'h0;
    else
      reg_def_start3 <= nxt_def_start3;
  end 
  assign o_def_start3 = reg_def_start3;
  //Assignment for next value of def_start4 rwi
  assign nxt_def_start4 = (we_def) ? reg_pwdata[26:25]
                        : (i_hw_we_def_start4) ? i_hw_wdata_def_start4
                        : reg_def_start4;
  //FF for bit def_start4
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_def_start4 <= 2'h0;
    else
      reg_def_start4 <= nxt_def_start4;
  end 
  assign o_def_start4 = reg_def_start4;

  //--------------------------------------------------------------------
  //Combine the value of def
  //--------------------------------------------------------------------
  always_comb begin
    def_value[31] = reg_def_start0;
    def_value[30] = reg_def_start1;
    def_value[29] = reg_def_start2;
    def_value[28:27] = reg_def_start3;
    def_value[26:25] = reg_def_start4;
    def_value[24:0] = '0;
  end
  //--------------------------------------------------------------------
  //O_PRDATA phase
  //--------------------------------------------------------------------
  always_comb begin
    case (reg_address)
      PARA_ABC_OFFSET: nxt_prdata = abc_value;
      PARA_DEF_OFFSET: nxt_prdata = def_value;
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

endmodule: m_vlsi_csr