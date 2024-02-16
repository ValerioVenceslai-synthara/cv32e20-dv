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



`define RVFI_INSTR_PATH rvfi_instr_if
`define RVFI_CSR_PATH   rvfi_csr_if
`define DUT_PATH        cv32e20_top_i
`define CSR_PATH        `DUT_PATH.u_cve2_top.u_cve2_core.cs_registers_i


    assign `RVFI_CSR_PATH.rvfi_csr_rdata = `CSR_PATH.csr_rdata_int;
    assign `RVFI_CSR_PATH.rvfi_csr_wdata = `CSR_PATH.csr_wdata_int;
    assign `RVFI_CSR_PATH.rvfi_csr_rmask = (~ `CSR_PATH.csr_wr & `CSR_PATH.csr_op_en_i & ~`CSR_PATH.illegal_csr_insn_o) ? -1 : 0;
    assign `RVFI_CSR_PATH.rvfi_csr_wmask = (`CSR_PATH.csr_we_int) ? -1 : 0;


`define RVFI_SET_CSR(CSR_ADDR, CSR_NAME) \
    assign `RVFI_CSR_PATH.rvfi_named_csr_rdata[``CSR_ADDR``] = `CSR_PATH.``CSR_NAME``_q; \
    assign `RVFI_CSR_PATH.rvfi_named_csr_wdata[``CSR_ADDR``] = `CSR_PATH.``CSR_NAME``_d; \
    assign `RVFI_CSR_PATH.rvfi_named_csr_rmask[``CSR_ADDR``] = (`CSR_PATH.csr_wr & `CSR_PATH.csr_op_en_i & ~`CSR_PATH.illegal_csr_insn_o & (`CSR_PATH.csr_addr_i == CSR_ADDR)) ? -1 : 0; \
    assign `RVFI_CSR_PATH.rvfi_named_csr_wmask[``CSR_ADDR``] = (`CSR_PATH.csr_we_int & (`CSR_PATH.csr_addr_i == CSR_ADDR)) ? -1 : 0;


   `RVFI_SET_CSR( `CSR_MSTATUS_ADDR,       mstatus       )
   `RVFI_SET_CSR( `CSR_MIE_ADDR,           mie           )
   `RVFI_SET_CSR( `CSR_MTVEC_ADDR,         mtvec         )
   `RVFI_SET_CSR( `CSR_MEPC_ADDR,          mepc          )
   `RVFI_SET_CSR( `CSR_MCAUSE_ADDR,        mcause        )
   `RVFI_SET_CSR( `CSR_MTVAL_ADDR,         mtval         )

//   `RVFI_SET_CSR( `CSR_JVT_ADDR,           jvt           )
//   `RVFI_SET_CSR( `CSR_MISA_ADDR,          misa          )
//   `RVFI_SET_CSR( `CSR_MCOUNTEREN_ADDR,    mcounteren    )
//   `RVFI_SET_CSR( `CSR_MENVCFG_ADDR,       menvcfg       )
//   `RVFI_SET_CSR( `CSR_MSTATEEN0_ADDR,     mstateen0     )
//   `RVFI_SET_CSR( `CSR_MSTATEEN1_ADDR,     mstateen1     )
//   `RVFI_SET_CSR( `CSR_MSTATEEN2_ADDR,     mstateen2     )
//   `RVFI_SET_CSR( `CSR_MSTATEEN3_ADDR,     mstateen3     )

//   `RVFI_SET_CSR( `CSR_MSTATUSH_ADDR,      mstatush      )
//   `RVFI_SET_CSR( `CSR_MENVCFGH_ADDR,      menvcfgh      )
//   `RVFI_SET_CSR( `CSR_MSTATEEN0H_ADDR,    mstateen0h    )
//   `RVFI_SET_CSR( `CSR_MSTATEEN1H_ADDR,    mstateen1h    )
//   `RVFI_SET_CSR( `CSR_MSTATEEN2H_ADDR,    mstateen2h    )
//   `RVFI_SET_CSR( `CSR_MSTATEEN3H_ADDR,    mstateen3h    )
//   `RVFI_SET_CSR( `CSR_MCOUNTINHIBIT_ADDR, mcountinhibit )

//   `RVFI_SET_CSR( `CSR_MHPMEVENT3_ADDR,    mhpmevent3    )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT4_ADDR,    mhpmevent4    )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT5_ADDR,    mhpmevent5    )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT6_ADDR,    mhpmevent6    )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT7_ADDR,    mhpmevent7    )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT8_ADDR,    mhpmevent8    )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT9_ADDR,    mhpmevent9    )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT10_ADDR,   mhpmevent10   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT11_ADDR,   mhpmevent11   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT12_ADDR,   mhpmevent12   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT13_ADDR,   mhpmevent13   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT14_ADDR,   mhpmevent14   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT15_ADDR,   mhpmevent15   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT16_ADDR,   mhpmevent16   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT17_ADDR,   mhpmevent17   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT18_ADDR,   mhpmevent18   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT19_ADDR,   mhpmevent19   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT20_ADDR,   mhpmevent20   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT21_ADDR,   mhpmevent21   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT22_ADDR,   mhpmevent22   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT23_ADDR,   mhpmevent23   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT24_ADDR,   mhpmevent24   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT25_ADDR,   mhpmevent25   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT26_ADDR,   mhpmevent26   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT27_ADDR,   mhpmevent27   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT28_ADDR,   mhpmevent28   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT29_ADDR,   mhpmevent29   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT30_ADDR,   mhpmevent30   )
//   `RVFI_SET_CSR( `CSR_MHPMEVENT31_ADDR,   mhpmevent31   )

//   `RVFI_SET_CSR( `CSR_MSCRATCH_ADDR,      mscratch      )
//   `RVFI_SET_CSR( `CSR_MIP_ADDR,           mip           )

//   `RVFI_SET_CSR( `CSR_PMPCFG0_ADDR,       pmpcfg0       )
//   `RVFI_SET_CSR( `CSR_PMPCFG1_ADDR,       pmpcfg1       )
//   `RVFI_SET_CSR( `CSR_PMPCFG2_ADDR,       pmpcfg2       )
//   `RVFI_SET_CSR( `CSR_PMPCFG3_ADDR,       pmpcfg3       )
//   `RVFI_SET_CSR( `CSR_PMPCFG4_ADDR,       pmpcfg4       )
//   `RVFI_SET_CSR( `CSR_PMPCFG5_ADDR,       pmpcfg5       )
//   `RVFI_SET_CSR( `CSR_PMPCFG6_ADDR,       pmpcfg6       )
//   `RVFI_SET_CSR( `CSR_PMPCFG7_ADDR,       pmpcfg7       )
//   `RVFI_SET_CSR( `CSR_PMPCFG8_ADDR,       pmpcfg8       )
//   `RVFI_SET_CSR( `CSR_PMPCFG9_ADDR,       pmpcfg9       )
//   `RVFI_SET_CSR( `CSR_PMPCFG10_ADDR,      pmpcfg10      )
//   `RVFI_SET_CSR( `CSR_PMPCFG11_ADDR,      pmpcfg11      )
//   `RVFI_SET_CSR( `CSR_PMPCFG12_ADDR,      pmpcfg12      )
//   `RVFI_SET_CSR( `CSR_PMPCFG13_ADDR,      pmpcfg13      )
//   `RVFI_SET_CSR( `CSR_PMPCFG14_ADDR,      pmpcfg14      )
//   `RVFI_SET_CSR( `CSR_PMPCFG15_ADDR,      pmpcfg15      )
//
//   `RVFI_SET_CSR( `CSR_PMPADDR0_ADDR,      pmpaddr0      )
//   `RVFI_SET_CSR( `CSR_PMPADDR1_ADDR,      pmpaddr1      )
//   `RVFI_SET_CSR( `CSR_PMPADDR2_ADDR,      pmpaddr2      )
//   `RVFI_SET_CSR( `CSR_PMPADDR3_ADDR,      pmpaddr3      )
//   `RVFI_SET_CSR( `CSR_PMPADDR4_ADDR,      pmpaddr4      )
//   `RVFI_SET_CSR( `CSR_PMPADDR5_ADDR,      pmpaddr5      )
//   `RVFI_SET_CSR( `CSR_PMPADDR6_ADDR,      pmpaddr6      )
//   `RVFI_SET_CSR( `CSR_PMPADDR7_ADDR,      pmpaddr7      )
//   `RVFI_SET_CSR( `CSR_PMPADDR8_ADDR,      pmpaddr8      )
//   `RVFI_SET_CSR( `CSR_PMPADDR9_ADDR,      pmpaddr9      )
//   `RVFI_SET_CSR( `CSR_PMPADDR10_ADDR,     pmpaddr10     )
//   `RVFI_SET_CSR( `CSR_PMPADDR11_ADDR,     pmpaddr11     )
//   `RVFI_SET_CSR( `CSR_PMPADDR12_ADDR,     pmpaddr12     )
//   `RVFI_SET_CSR( `CSR_PMPADDR13_ADDR,     pmpaddr13     )
//   `RVFI_SET_CSR( `CSR_PMPADDR14_ADDR,     pmpaddr14     )
//   `RVFI_SET_CSR( `CSR_PMPADDR15_ADDR,     pmpaddr15     )
//   `RVFI_SET_CSR( `CSR_PMPADDR16_ADDR,     pmpaddr16     )
//   `RVFI_SET_CSR( `CSR_PMPADDR17_ADDR,     pmpaddr17     )
//   `RVFI_SET_CSR( `CSR_PMPADDR18_ADDR,     pmpaddr18     )
//   `RVFI_SET_CSR( `CSR_PMPADDR19_ADDR,     pmpaddr19     )
//   `RVFI_SET_CSR( `CSR_PMPADDR20_ADDR,     pmpaddr20     )
//   `RVFI_SET_CSR( `CSR_PMPADDR21_ADDR,     pmpaddr21     )
//   `RVFI_SET_CSR( `CSR_PMPADDR22_ADDR,     pmpaddr22     )
//   `RVFI_SET_CSR( `CSR_PMPADDR23_ADDR,     pmpaddr23     )
//   `RVFI_SET_CSR( `CSR_PMPADDR24_ADDR,     pmpaddr24     )
//   `RVFI_SET_CSR( `CSR_PMPADDR25_ADDR,     pmpaddr25     )
//   `RVFI_SET_CSR( `CSR_PMPADDR26_ADDR,     pmpaddr26     )
//   `RVFI_SET_CSR( `CSR_PMPADDR27_ADDR,     pmpaddr27     )
//   `RVFI_SET_CSR( `CSR_PMPADDR28_ADDR,     pmpaddr28     )
//   `RVFI_SET_CSR( `CSR_PMPADDR29_ADDR,     pmpaddr29     )
//   `RVFI_SET_CSR( `CSR_PMPADDR30_ADDR,     pmpaddr30     )
//   `RVFI_SET_CSR( `CSR_PMPADDR31_ADDR,     pmpaddr31     )
//   `RVFI_SET_CSR( `CSR_PMPADDR32_ADDR,     pmpaddr32     )
//   `RVFI_SET_CSR( `CSR_PMPADDR33_ADDR,     pmpaddr33     )
//   `RVFI_SET_CSR( `CSR_PMPADDR34_ADDR,     pmpaddr34     )
//   `RVFI_SET_CSR( `CSR_PMPADDR35_ADDR,     pmpaddr35     )
//   `RVFI_SET_CSR( `CSR_PMPADDR36_ADDR,     pmpaddr36     )
//   `RVFI_SET_CSR( `CSR_PMPADDR37_ADDR,     pmpaddr37     )
//   `RVFI_SET_CSR( `CSR_PMPADDR38_ADDR,     pmpaddr38     )
//   `RVFI_SET_CSR( `CSR_PMPADDR39_ADDR,     pmpaddr39     )
//   `RVFI_SET_CSR( `CSR_PMPADDR40_ADDR,     pmpaddr40     )
//   `RVFI_SET_CSR( `CSR_PMPADDR41_ADDR,     pmpaddr41     )
//   `RVFI_SET_CSR( `CSR_PMPADDR42_ADDR,     pmpaddr42     )
//   `RVFI_SET_CSR( `CSR_PMPADDR43_ADDR,     pmpaddr43     )
//   `RVFI_SET_CSR( `CSR_PMPADDR44_ADDR,     pmpaddr44     )
//   `RVFI_SET_CSR( `CSR_PMPADDR45_ADDR,     pmpaddr45     )
//   `RVFI_SET_CSR( `CSR_PMPADDR46_ADDR,     pmpaddr46     )
//   `RVFI_SET_CSR( `CSR_PMPADDR47_ADDR,     pmpaddr47     )
//   `RVFI_SET_CSR( `CSR_PMPADDR48_ADDR,     pmpaddr48     )
//   `RVFI_SET_CSR( `CSR_PMPADDR49_ADDR,     pmpaddr49     )
//   `RVFI_SET_CSR( `CSR_PMPADDR50_ADDR,     pmpaddr50     )
//   `RVFI_SET_CSR( `CSR_PMPADDR51_ADDR,     pmpaddr51     )
//   `RVFI_SET_CSR( `CSR_PMPADDR52_ADDR,     pmpaddr52     )
//   `RVFI_SET_CSR( `CSR_PMPADDR53_ADDR,     pmpaddr53     )
//   `RVFI_SET_CSR( `CSR_PMPADDR54_ADDR,     pmpaddr54     )
//   `RVFI_SET_CSR( `CSR_PMPADDR55_ADDR,     pmpaddr55     )
//   `RVFI_SET_CSR( `CSR_PMPADDR56_ADDR,     pmpaddr56     )
//   `RVFI_SET_CSR( `CSR_PMPADDR57_ADDR,     pmpaddr57     )
//   `RVFI_SET_CSR( `CSR_PMPADDR58_ADDR,     pmpaddr58     )
//   `RVFI_SET_CSR( `CSR_PMPADDR59_ADDR,     pmpaddr59     )
//   `RVFI_SET_CSR( `CSR_PMPADDR60_ADDR,     pmpaddr60     )
//   `RVFI_SET_CSR( `CSR_PMPADDR61_ADDR,     pmpaddr61     )
//   `RVFI_SET_CSR( `CSR_PMPADDR62_ADDR,     pmpaddr62     )
//   `RVFI_SET_CSR( `CSR_PMPADDR63_ADDR,     pmpaddr63     )

//   `RVFI_SET_CSR( `CSR_MSECCFG_ADDR,       mseccfg       )
//   `RVFI_SET_CSR( `CSR_MSECCFGH_ADDR,      mseccfgh      )

//   if (CORE_PARAM_DBG_NUM_TRIGGERS > 0) begin
//     `RVFI_SET_CSR( `CSR_TSELECT_ADDR,       tselect       )
//     `RVFI_SET_CSR( `CSR_TDATA1_ADDR,        tdata1        )
//     `RVFI_SET_CSR( `CSR_TDATA2_ADDR,        tdata2        )
//     `RVFI_SET_CSR( `CSR_TINFO_ADDR,         tinfo         )
//   end

//   `RVFI_SET_CSR( `CSR_DCSR_ADDR,          dcsr          )
//   `RVFI_SET_CSR( `CSR_DPC_ADDR,           dpc           )
//   `RVFI_SET_CSR( `CSR_DSCRATCH0_ADDR,     dscratch0     )
//   `RVFI_SET_CSR( `CSR_DSCRATCH1_ADDR,     dscratch1     )

//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER3_ADDR, mhpmcounter3   )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER4_ADDR, mhpmcounter4   )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER5_ADDR, mhpmcounter5   )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER6_ADDR, mhpmcounter6   )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER7_ADDR, mhpmcounter7   )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER8_ADDR, mhpmcounter8   )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER9_ADDR, mhpmcounter9   )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER10_ADDR, mhpmcounter10 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER11_ADDR, mhpmcounter11 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER12_ADDR, mhpmcounter12 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER13_ADDR, mhpmcounter13 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER14_ADDR, mhpmcounter14 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER15_ADDR, mhpmcounter15 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER16_ADDR, mhpmcounter16 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER17_ADDR, mhpmcounter17 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER18_ADDR, mhpmcounter18 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER19_ADDR, mhpmcounter19 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER20_ADDR, mhpmcounter20 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER21_ADDR, mhpmcounter21 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER22_ADDR, mhpmcounter22 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER23_ADDR, mhpmcounter23 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER24_ADDR, mhpmcounter24 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER25_ADDR, mhpmcounter25 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER26_ADDR, mhpmcounter26 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER27_ADDR, mhpmcounter27 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER28_ADDR, mhpmcounter28 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER29_ADDR, mhpmcounter29 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER30_ADDR, mhpmcounter30 )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER31_ADDR, mhpmcounter31 )

//   `RVFI_SET_CSR( `CSR_MCYCLE_ADDR,        mcycle        )
//   `RVFI_SET_CSR( `CSR_MINSTRET_ADDR,      minstret      )

//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER3H_ADDR, mhpmcounter3h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER4H_ADDR, mhpmcounter4h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER5H_ADDR, mhpmcounter5h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER6H_ADDR, mhpmcounter6h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER7H_ADDR, mhpmcounter7h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER8H_ADDR, mhpmcounter8h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER9H_ADDR, mhpmcounter9h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER10H_ADDR,mhpmcounter10h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER11H_ADDR,mhpmcounter11h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER12H_ADDR,mhpmcounter12h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER13H_ADDR,mhpmcounter13h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER14H_ADDR,mhpmcounter14h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER15H_ADDR,mhpmcounter15h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER16H_ADDR,mhpmcounter16h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER17H_ADDR,mhpmcounter17h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER18H_ADDR,mhpmcounter18h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER19H_ADDR,mhpmcounter19h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER20H_ADDR,mhpmcounter20h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER21H_ADDR,mhpmcounter21h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER22H_ADDR,mhpmcounter22h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER23H_ADDR,mhpmcounter23h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER24H_ADDR,mhpmcounter24h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER25H_ADDR,mhpmcounter25h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER26H_ADDR,mhpmcounter26h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER27H_ADDR,mhpmcounter27h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER28H_ADDR,mhpmcounter28h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER29H_ADDR,mhpmcounter29h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER30H_ADDR,mhpmcounter30h )
//   `RVFI_SET_CSR( `CSR_MHPMCOUNTER31H_ADDR,mhpmcounter31h )

//   `RVFI_SET_CSR( `CSR_CPUCTRL_ADDR,       cpuctrl       )
//   `RVFI_SET_CSR( `CSR_SECURESEED0_ADDR,   secureseed0   )
//   `RVFI_SET_CSR( `CSR_SECURESEED1_ADDR,   secureseed1   )
//   `RVFI_SET_CSR( `CSR_SECURESEED2_ADDR,   secureseed2   )

//   `RVFI_SET_CSR( `CSR_MVENDORID_ADDR,     mvendorid     )
//   `RVFI_SET_CSR( `CSR_MARCHID_ADDR,       marchid       )
//   `RVFI_SET_CSR( `CSR_MIMPID_ADDR,        mimpid        )
//   `RVFI_SET_CSR( `CSR_MHARTID_ADDR,       mhartid       )
//   `RVFI_SET_CSR( `CSR_MCONFIGPTR_ADDR,    mconfigptr    )

//   `RVFI_SET_CSR( `CSR_MCYCLEH_ADDR,       mcycleh       )
//   `RVFI_SET_CSR( `CSR_MINSTRETH_ADDR,     minstreth     )

 //  if (CORE_PARAM_CLIC == 1) begin
 //    `RVFI_SET_CSR( `CSR_MTVT_ADDR,        mtvt          )
 //    `RVFI_SET_CSR( `CSR_MNXTI_ADDR,       mnxti         )
 //    `RVFI_SET_CSR( `CSR_MINTSTATUS_ADDR,  mintstatus    )
 //    `RVFI_SET_CSR( `CSR_MINTTHRESH_ADDR,  mintthresh    )
 //    `RVFI_SET_CSR( `CSR_MSCRATCHCSW_ADDR, mscratchcsw   )
 //    `RVFI_SET_CSR( `CSR_MSCRATCHCSWL_ADDR,mscratchcswl  )
 //  end


endmodule : uvmt_cv32e20_dut_wrap

`endif // __UVMT_CV32E20_DUT_WRAP_SV__


