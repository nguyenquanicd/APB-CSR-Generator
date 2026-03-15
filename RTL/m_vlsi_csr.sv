`timescale 1ns/1ps
//--------------------------------------------------------------------
// Project: APB-CSR-Generator
// Generator: ltthinh
// Date and time: 2026-03-15 14:23:48.414717
// Module: m_vlsi_csr
// Function: Control & Status register via APB interface
// Page: VLSI Technology
//--------------------------------------------------------------------
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
  input i_reg_clk,
  input i_reg_rstn,
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
  logic read_ack;
  logic read_ack_bus_clk;
  logic reg_read_req;
  logic reg_read_ack_reg_clk_dly;
  logic read_aclk_bus_clk_falling;
  logic write_ack;
  logic write_ack_bus_clk;
  logic reg_write_req;
  logic reg_write_ack_reg_clk_dly;
  logic write_aclk_bus_clk_falling;
  logic read_req_reg_clk;
  logic reg_read_req_reg_clk_dly;
  logic write_req_reg_clk;
  logic reg_write_req_reg_clk_dly;
  logic reg_read_ack_bus_clk_dly;
  logic reg_write_ack_bus_clk_dly;
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


  //APB handshake synchronization (appear when option Async is selected) - START
  //--------------------------------------------------------------------
  //Bus clock - reading phase
  //--------------------------------------------------------------------
  m_vlsi_synch #(
    .PARA_LEVELS (2)
  ) u_read_ack_reg2bus (
    .i_clk (i_bus_clk),
    .i_rstn (i_bus_rstn),
    .i_data_in (read_ack),
    .o_data_out (read_ack_bus_clk)
  );
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_read_req <= '0;
    else begin
      casez ({read_ack_bus_clk, apb_read})
        2'b1?: reg_read_req <= '0;
        2'b01: reg_read_req <= '1;
        2'b00: reg_read_req <= reg_read_req;
        default: reg_read_req <= 'x;
      endcase
    end
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_read_ack_bus_clk_dly <= '0;
    else
      reg_read_ack_bus_clk_dly <= read_ack_bus_clk;
  end
  assign read_aclk_bus_clk_falling = reg_read_ack_bus_clk_dly & ~read_ack_bus_clk;

  //--------------------------------------------------------------------
  //Bus clock - writing phase
  //--------------------------------------------------------------------
  m_vlsi_synch #(
    .PARA_LEVELS (2)
  ) u_write_ack_reg2bus (
    .i_clk (i_bus_clk),
    .i_rstn (i_bus_rstn),
    .i_data_in (write_ack),
    .o_data_out (write_ack_bus_clk)
  );
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_write_req <= '0;
    else begin
      casez ({write_ack_bus_clk, apb_write})
        2'b1?: reg_write_req <= '0;
        2'b01: reg_write_req <= '1;
        2'b00: reg_write_req <= reg_write_req;
        default: reg_write_req <= 'x;
      endcase
    end
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_write_ack_bus_clk_dly <= '0;
    else
      reg_write_ack_bus_clk_dly <= write_ack_bus_clk;
  end
  assign write_aclk_bus_clk_falling = reg_write_ack_bus_clk_dly & ~write_ack_bus_clk;

  //--------------------------------------------------------------------
  //Reg clock - reading handshake
  //--------------------------------------------------------------------
  m_vlsi_synch #(
    .PARA_LEVELS (2)
  ) u_rd_ack_reg2bus (
    .i_clk (i_reg_clk),
    .i_rstn (i_reg_rstn),
    .i_data_in (reg_read_req),
    .o_data_out (read_req_reg_clk)
  );
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin
    if(!i_reg_rstn) 
      reg_read_req_reg_clk_dly <= '0;
    else
      reg_read_req_reg_clk_dly <= read_req_reg_clk;
  end
  assign apb_read_en = ~reg_read_req_reg_clk_dly & read_req_reg_clk;
  assign read_ack = reg_read_req_reg_clk_dly;

  //--------------------------------------------------------------------
  //Reg clock - writing handshake
  //--------------------------------------------------------------------
  m_vlsi_synch #(
    .PARA_LEVELS (2)
  ) u_wr_ack_reg2bus (
    .i_clk (i_reg_clk),
    .i_rstn (i_reg_rstn),
    .i_data_in (reg_write_req),
    .o_data_out (write_req_reg_clk)
  );
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin
    if(!i_reg_rstn) 
      reg_write_req_reg_clk_dly <= '0;
    else
      reg_write_req_reg_clk_dly <= write_req_reg_clk;
  end
  assign apb_write_en = ~reg_write_req_reg_clk_dly & write_req_reg_clk;
  assign write_ack = reg_write_req_reg_clk_dly;

  //--------------------------------------------------------------------
  //PREADY phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_pready <= '0;
    else
      reg_pready <= read_aclk_bus_clk_falling // reading complete
                | write_aclk_bus_clk_falling // writing complete
                | (apb_slverr & apb_setup & i_slverr_en);//slverr assert
  end
  assign o_pready = reg_pready;
  //--------------------------------------------------------------------

  //Assignment for next value of abc_start1 rw
  assign nxt_abc_start1 = (we_abc) ? reg_pwdata[30] : reg_abc_start1;
  //FF for bit abc_start1
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
      reg_abc_start2 <= 1'h0;
    else
      reg_abc_start2 <= nxt_abc_start2;
  end 
  assign o_abc_start2 = reg_abc_start2;
  //Assignment for next value of abc_start3 rw
  assign nxt_abc_start3 = (we_abc) ? reg_pwdata[28:27] : reg_abc_start3;
  //FF for bit abc_start3
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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
  always_ff @ (posedge i_reg_clk, negedge i_reg_rstn) begin //FF for each bit
    if(!i_reg_rstn) 
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