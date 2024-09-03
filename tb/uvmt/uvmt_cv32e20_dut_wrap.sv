// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Copyright 2020,2023 OpenHW Group
// Copyright 2020 Datum Technology Corporation
// Copyright 2020 Silicon Labs, Inc.
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
///////////////////////////////////////////////////////////////////////////////


`ifndef __UVMT_CV32E20_DUT_WRAP_SV__
`define __UVMT_CV32E20_DUT_WRAP_SV__

import uvm_pkg::*; // needed for the UVM messaging service (`uvm_info(), etc.)
import cve2_pkg::*;// definitions of enumerated types used by cve2
import uvmt_cv32e20_pkg::*;

/**
 * Wrapper for the CV32E20 RTL DUT.
 * Includes the RVFI Tracer and the IBEX core.
 */
module uvmt_cv32e20_dut_wrap #(
                            // CV32E20 parameters.  See User Manual.
                            parameter int unsigned MHPMCounterNum    = 10,
                            parameter int unsigned MHPMCounterWidth  = 40,
                            parameter bit          RV32E             = 1'b0,
                            parameter rv32m_e      RV32M             = RV32MFast,
                            parameter bit          BranchPredictor   = 1'b0,
                            parameter int unsigned DmHaltAddr        = 32'h1A11_0800,
                            parameter int unsigned DmExceptionAddr   = 32'h1A14_0000,
                            // Remaining parameters are used by TB components only
                            parameter int unsigned INSTR_ADDR_WIDTH    =  32,
                            parameter int unsigned INSTR_RDATA_WIDTH   =  32,
                            parameter int unsigned RAM_ADDR_WIDTH      =  22
                           )

                           (
                            uvma_clknrst_if              clknrst_if,
                            uvma_interrupt_if            interrupt_if,
                            // vp_status_if is driven by ENV and used in TB
                            uvma_interrupt_if            vp_interrupt_if,
                            uvme_cv32e20_core_cntrl_if   core_cntrl_if,
                            uvmt_cv32e20_core_status_if  core_status_if,
                            uvma_obi_memory_if           obi_memory_instr_if,
                            uvma_obi_memory_if           obi_memory_data_if
                           );

    // signals connecting core to memory
    logic                         instr_req;
    logic                         instr_gnt;
    logic                         instr_rvalid;
    logic [INSTR_ADDR_WIDTH-1 :0] instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] instr_rdata;

    logic                         data_req;
    logic                         data_gnt;
    logic                         data_rvalid;
    logic [31:0]                  data_addr;
    logic                         data_we;
    logic [3:0]                   data_be;
    logic [31:0]                  data_rdata;
    logic [31:0]                  data_wdata;

    logic [31:0]                  irq_vp;
    logic [31:0]                  irq_uvma;
    logic [31:0]                  irq;
    logic                         irq_ack;
    logic [ 4:0]                  irq_id;

    logic                         debug_req_vp;
    logic                         debug_req_uvma;
    logic                         debug_req;
    logic                         debug_havereset;
    logic                         debug_running;
    logic                         debug_halted;

    assign debug_if.clk      = clknrst_if.clk;
    assign debug_if.reset_n  = clknrst_if.reset_n;
    assign debug_req_uvma    = debug_if.debug_req;

    assign debug_req = debug_req_vp | debug_req_uvma;

    // --------------------------------------------
    // Instruction bus is read-only, OBI v1.0
    assign obi_memory_instr_if.we        = 'b0;
    assign obi_memory_instr_if.be        = '1;
    // Data bus is read/write, OBI v1.0

    // --------------------------------------------
    // Connect to uvma_interrupt_if
    assign interrupt_if.clk                     = clknrst_if.clk;
    assign interrupt_if.reset_n                 = clknrst_if.reset_n;
    assign irq_uvma                             = interrupt_if.irq;
    assign interrupt_if.irq_id                  = cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.controller_i.exc_cause_o[4:0]; //irq_id;
//    assign interrupt_if.irq_ack                 = cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.controller_i.handle_irq; //irq_ack;
    assign interrupt_if.irq_ack                 = (cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.controller_i.ctrl_fsm_cs == 4'h7);//irq_ack

    assign vp_interrupt_if.clk                  = clknrst_if.clk;
    assign vp_interrupt_if.reset_n              = clknrst_if.reset_n;
    assign irq_vp                               = irq_uvma;
    // {irq_q[31:16], pending_enabled_irq_q[11], pending_enabled_irq_q[3], pending_enabled_irq_q[7]}
    // was vp_interrupt_if.irq;
    assign vp_interrupt_if.irq_id               = cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.controller_i.exc_cause_o[4:0];    //irq_id;
    assign vp_interrupt_if.irq_ack              = (cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.controller_i.ctrl_fsm_cs == 4'h7);//irq_ack

    assign irq = irq_uvma | irq_vp;

//---------------------------------------------------------------------------------
// CV-X-IF issue interface signals.
logic        xif_issue_valid;
logic        xif_issue_ready;
logic [31:0] xif_issue_req_instr;
logic        xif_issue_resp_accept;
logic        xif_issue_resp_writeback;
logic [2:0]  xif_issue_resp_register_read;

// CV-X-IF register interface signals.
logic        xif_register_ready;
logic [31:0] xif_register_rs1;
logic [31:0] xif_register_rs2;
logic [31:0] xif_register_rs3;
logic [2:0]  xif_register_rs_valid;

// CV-X-IF commit interface signals.
logic        xif_commit_valid;
logic        xif_commit_kill;

// CV-X-IF result interface signals.
logic        xif_result_ready;
logic        xif_result_valid;
logic        xif_result_we;
logic [31:0] xif_result_data;

// Flatten signals for the co-processor wrapper.
logic[$bits(x_issue_req_t_dtype)-1:0]  xif_issue_req_flatten;
logic[$bits(x_issue_resp_t_dtype)-1:0] xif_issue_resp_flatten;

logic[$bits(x_register_t_dtype)-1:0]   xif_register_flatten;

logic[$bits(x_commit_t_dtype)-1:0]     xif_commit_flatten;

logic[$bits(x_result_t_dtype)-1:0]     xif_result_flatten;
// Unused signals, just to simplify unpacking.
hartid_t_dtype                         xif_result_hartid;
id_t_dtype                             xif_result_id;

logic[$bits(data_csr_dtype)-1:0]       csr_vec_mode_flatten;

assign xif_issue_req_flatten = {xif_issue_req_instr, {$bits(hartid_t_dtype){1'b0}}, {$bits(id_t_dtype){1'b0}}}; // TODO add ID management
always_comb begin
       {xif_issue_resp_accept, xif_issue_resp_writeback, xif_issue_resp_register_read} = xif_issue_resp_flatten;
end
assign xif_register_flatten = {{$bits(hartid_t_dtype){1'b0}}, {$bits(id_t_dtype){1'b0}}, {xif_register_rs3, xif_register_rs2, xif_register_rs1}, xif_register_rs_valid};
assign xif_commit_flatten =  {{$bits(hartid_t_dtype){1'b0}}, {$bits(id_t_dtype){1'b0}}, xif_commit_kill};
always_comb begin
       {xif_result_hartid, xif_result_id, xif_result_data, xif_result_we, xif_result_data} = xif_result_flatten;
end
assign csr_vec_mode_flatten = 32'd3; // Fixed word width vec mode
//---------------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Instantiate the core
//    cve2_top #(
    cve2_top_tracing #(
               .MHPMCounterNum   (MHPMCounterNum),
               .MHPMCounterWidth (MHPMCounterWidth),
               .RV32E            (RV32E),
               .RV32M            (RV32M),
               .DmHaltAddr       (DmHaltAddr),
               .DmExceptionAddr  (DmExceptionAddr)
              )
    cv32e20_top_i
        (
         .clk_i                  ( clknrst_if.clk                 ),
         .rst_ni                 ( clknrst_if.reset_n             ),

         .test_en_i              ( 1'b1                           ), // enable all clock gates for testing
         .ram_cfg_i              ( prim_ram_1p_pkg::RAM_1P_CFG_DEFAULT ),

         .hart_id_i              ( 32'h0000_0000                  ),
         .boot_addr_i            ( core_cntrl_if.boot_addr       ), //<---MJS changing to 0

  // Instruction memory interface
         .instr_req_o            ( obi_memory_instr_if.req        ), // core to agent
         .instr_gnt_i            ( obi_memory_instr_if.gnt        ), // agent to core
         .instr_rvalid_i         ( obi_memory_instr_if.rvalid     ),
         .instr_addr_o           ( obi_memory_instr_if.addr       ),
         .instr_rdata_i          ( obi_memory_instr_if.rdata      ),
         .instr_err_i            ( '0                             ),

  // Data memory interface
         .data_req_o             ( obi_memory_data_if.req         ),
         .data_gnt_i             ( obi_memory_data_if.gnt         ),
         .data_rvalid_i          ( obi_memory_data_if.rvalid      ),
         .data_we_o              ( obi_memory_data_if.we          ),
         .data_be_o              ( obi_memory_data_if.be          ),
         .data_addr_o            ( obi_memory_data_if.addr        ),
         .data_wdata_o           ( obi_memory_data_if.wdata       ),
         .data_rdata_i           ( obi_memory_data_if.rdata       ),
         .data_err_i             ( '0                             ),

//---------------------------------------------------------------------------------
  // CV-X-IF
  // Issue interface
         .xif_issue_valid_o(xif_issue_valid),
         .xif_issue_req_instr_o(xif_issue_req_instr),
         .xif_issue_ready_i(xif_issue_ready),
         .xif_issue_resp_accept_i(xif_issue_resp_accept),
         .xif_issue_resp_writeback_i(xif_issue_resp_writeback),
         .xif_issue_resp_register_read_i(xif_issue_resp_register_read),
  // Register interface
         .xif_register_rs1_o(xif_register_rs1),
         .xif_register_rs2_o(xif_register_rs2),
         .xif_register_rs3_o(xif_register_rs3),
         .xif_register_rs_valid_o(xif_register_rs_valid),
  // Commit interface
         .xif_commit_valid_o(xif_commit_valid),
         .xif_commit_kill_o(xif_commit_kill),
  // Result interface
         .xif_result_ready_o(xif_result_ready),
         .xif_result_valid_i(xif_result_valid),
         .xif_result_we_i(xif_result_we),
         .xif_result_data_i(xif_result_data),
//---------------------------------------------------------------------------------

  // Interrupt inputs
         .irq_software_i         ( irq_uvma[3]),
         .irq_timer_i            ( irq_uvma[7]),
         .irq_external_i         ( irq_uvma[11]),
         .irq_fast_i             ( irq_uvma[31:16]),
         .irq_nm_i               ( irq_uvma[0]),       // non-maskeable interrupt

  // Debug Interface
         .debug_req_i             (debug_req_uvma),
         .crash_dump_o            (),

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follows
  // the convention of RISC-V Formal Interface Specification.
  // CPU Control Signals
         .fetch_enable_i          (core_cntrl_if.fetch_en), // fetch_enable_t
         .core_sleep_o            ()
        );

//---------------------------------------------------------------------------------
// Instantiate the co-processor
      rvv_xcs_wrp i_rvv_xcs_wrp(
       //std if signals.
       .clk(clknrst_if.clk),
       .resetn(clknrst_if.reset_n),

       //cv-x-if Issue interface signals.
       .issue_valid(xif_issue_valid),
       .issue_ready(xif_issue_ready),
       .issue_req_flatten(xif_issue_req_flatten),
       .issue_resp_flatten(xif_issue_resp_flatten),

       //cv-x-if Register interface signals.
       .register_valid(xif_issue_valid),
       .register_ready(xif_register_ready),
       .register_flatten(xif_register_flatten),

       //cv-x-if Commit interface signals.
       .commit_valid(xif_commit_valid),
       .commit_flatten(xif_commit_flatten),

       //cv-x-if Result interface signals.
       .result_ready(xif_result_ready),
       .result_valid(xif_result_valid),
       .result_flatten(xif_result_flatten),

       //CSR vec mode.
       .csr_vec_mode_flatten(csr_vec_mode_flatten)
      );
//---------------------------------------------------------------------------------



`define RVFI_INSTR_PATH rvfi_instr_if
`define RVFI_CSR_PATH   rvfi_csr_if
`define DUT_PATH        cv32e20_top_i
`define CSR_PATH        `DUT_PATH.u_cve2_top.u_cve2_core.cs_registers_i


endmodule : uvmt_cv32e20_dut_wrap

`endif // __UVMT_CV32E20_DUT_WRAP_SV__


