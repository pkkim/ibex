// Copyright lowRISC contributors.
// Copyright 2018 ETH Zurich and University of Bologna, see also CREDITS.md.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Arithmetic logic unit
 */
module ibex_alu #(
  parameter ibex_pkg::rv32b_e RV32B = ibex_pkg::RV32BNone
) (
  input  ibex_pkg::alu_op_e operator_i,
  input  logic [31:0]       operand_a_i,
  input  logic [31:0]       operand_b_i,

  input  logic              instr_first_cycle_i,

  input  logic [32:0]       multdiv_operand_a_i,
  input  logic [32:0]       multdiv_operand_b_i,

  input  logic              multdiv_sel_i,

  input  logic [31:0]       imd_val_q_i[2],
  output logic [31:0]       imd_val_d_o[2],
  output logic [1:0]        imd_val_we_o,

  output logic [31:0]       adder_result_o,
  output logic [33:0]       adder_result_ext_o,

  output logic [31:0]       result_o,
  output logic              comparison_result_o,
  output logic              is_equal_result_o
);

  ///////////
  // Adder //
  ///////////

  ////////////////
  // Comparison //
  ////////////////


  // GTE unsigned:
  // (a[31] == 1 && b[31] == 1) => adder_result[31] == 0
  // (a[31] == 0 && b[31] == 0) => adder_result[31] == 0
  // (a[31] == 1 && b[31] == 0) => 1
  // (a[31] == 0 && b[31] == 1) => 0

  // GTE signed:
  // (a[31] == 1 && b[31] == 1) => adder_result[31] == 0
  // (a[31] == 0 && b[31] == 0) => adder_result[31] == 0
  // (a[31] == 1 && b[31] == 0) => 0
  // (a[31] == 0 && b[31] == 1) => 1


  ///////////
  // Shift //
  ///////////

  // The shifter structure consists of a 33-bit shifter: 32-bit operand + 1 bit extension for
  // arithmetic shifts and one-shift support.
  // Rotations and funnel shifts are implemented as multi-cycle instructions.
  // The shifter is also used for single-bit instructions and bit-field place as detailed below.
  //
  // Standard Shifts
  // ===============
  // For standard shift instructions, the direction of the shift is to the right by default. For
  // left shifts, the signal shift_left signal is set. If so, the operand is initially reversed,
  // shifted to the right by the specified amount and shifted back again. For arithmetic- and
  // one-shifts the 33rd bit of the shifter operand can is set accordingly.
  //
  // Multicycle Shifts
  // =================
  //
  // Rotation
  // --------
  // For rotations, the operand signals operand_a_i and operand_b_i are kept constant to rs1 and
  // rs2 respectively.
  //
  // Rotation pseudocode:
  //   shift_amt = rs2 & 31;
  //   multicycle_result = (rs1 >> shift_amt) | (rs1 << (32 - shift_amt));
  //                       ^-- cycle 0 -----^ ^-- cycle 1 --------------^
  //
  // Funnel Shifts
  // -------------
  // For funnel shifs, operand_a_i is tied to rs1 in the first cycle and rs3 in the
  // second cycle. operand_b_i is always tied to rs2. The order of applying the shift amount or
  // its complement is determined by bit [5] of shift_amt.
  //
  // Funnel shift Pseudocode: (fsl)
  //  shift_amt = rs2 & 63;
  //  shift_amt_compl = 32 - shift_amt[4:0]
  //  if (shift_amt >=33):
  //     multicycle_result = (rs1 >> shift_amt_compl[4:0]) | (rs3 << shift_amt[4:0]);
  //                         ^-- cycle 0 ----------------^ ^-- cycle 1 ------------^
  //  else if (shift_amt <= 31 && shift_amt > 0):
  //     multicycle_result = (rs1 << shift_amt[4:0]) | (rs3 >> shift_amt_compl[4:0]);
  //                         ^-- cycle 0 ----------^ ^-- cycle 1 -------------------^
  //  For shift_amt == 0, 32, both shift_amt[4:0] and shift_amt_compl[4:0] == '0.
  //  these cases need to be handled separately outside the shifting structure:
  //  else if (shift_amt == 32):
  //     multicycle_result = rs3
  //  else if (shift_amt == 0):
  //     multicycle_result = rs1.
  //
  // Single-Bit Instructions
  // =======================
  // Single bit instructions operate on bit operand_b_i[4:0] of operand_a_i.

  // The operations bset, bclr and binv are implemented by generation of a bit-mask using the
  // shifter structure. This is done by left-shifting the operand 32'h1 by the required amount.
  // The signal shift_sbmode multiplexes the shifter input and sets the signal shift_left.
  // Further processing is taken care of by a separate structure.
  //
  // For bext, the bit defined by operand_b_i[4:0] is to be returned. This is done by simply
  // shifting operand_a_i to the right by the required amount and returning bit [0] of the result.
  //
  // Bit-Field Place
  // ===============
  // The shifter structure is shared to compute bfp_mask << bfp_off.


  /////////////////////////////////
  // Bitwise Logic: or, and, xor //
  /////////////////////////////////


    /////////////////
    // Bitcounting //
    /////////////////


    ///////////////
    // Min / Max //
    ///////////////

    //////////
    // Pack //
    //////////


    //////////
    // Sext //
    //////////

    /////////////////////////////
    // Single-bit Instructions //
    /////////////////////////////

    ////////////////////////////////////
    // General Reverse and Or-combine //
    ////////////////////////////////////

      /////////////////////////
      // Shuffle / Unshuffle //
      /////////////////////////

      //////////////
      // Crossbar //
      //////////////

      ///////////////////////////////////////////////////
      // Carry-less Multiply + Cyclic Redundancy Check //
      ///////////////////////////////////////////////////

      // Carry-less multiplication can be understood as multiplication based on
      // the addition interpreted as the bit-wise xor operation.
      //
      // Example: 1101 X 1011 = 1111111:
      //
      //       1011 X 1101
      //       -----------
      //              1101
      //         xor 1101
      //         ---------
      //             10111
      //        xor 0000
      //        ----------
      //            010111
      //       xor 1101
      //       -----------
      //           1111111
      //
      // Architectural details:
      //         A 32 x 32-bit array
      //         [ operand_b[i] ? (operand_a << i) : '0 for i in 0 ... 31 ]
      //         is generated. The entries of the array are pairwise 'xor-ed'
      //         together in a 5-stage binary tree.
      //
      //
      // Cyclic Redundancy Check:
      //
      // CRC-32 (CRC-32/ISO-HDLC) and CRC-32C (CRC-32/ISCSI) are directly implemented. For
      // documentation of the crc configuration (crc-polynomials, initialization, reflection, etc.)
      // see http://reveng.sourceforge.net/crc-catalogue/all.htm
      // A useful guide to crc arithmetic and algorithms is given here:
      // http://www.piclist.com/techref/method/math/crcguide.html.
      //
      // The CRC operation solves the following equation using binary polynomial arithmetic:
      //
      // rev(rd)(x) = rev(rs1)(x) * x**n mod {1, P}(x)
      //
      // where P denotes lower 32 bits of the corresponding CRC polynomial, rev(a) the bit reversal
      // of a, n = 8,16, or 32 for .b, .h, .w -variants. {a, b} denotes bit concatenation.
      //
      // Using barret reduction, one can show that
      //
      // M(x) mod P(x) = R(x) =
      //          (M(x) * x**n) & {deg(P(x)'{1'b1}}) ^ (M(x) x**-(deg(P(x) - n)) cx mu(x) cx P(x),
      //
      // Where mu(x) = polydiv(x**64, {1,P}) & 0xffffffff. Here, 'cx' refers to carry-less
      // multiplication. Substituting rev(rd)(x) for R(x) and rev(rs1)(x) for M(x) and solving for
      // rd(x) with P(x) a crc32 polynomial (deg(P(x)) = 32), we get
      //
      // rd = rev( (rev(rs1) << n)  ^ ((rev(rs1) >> (32-n)) cx mu cx P)
      //    = (rs1 >> n) ^ rev(rev( (rs1 << (32-n)) cx rev(mu)) cx P)
      //                       ^-- cycle 0--------------------^
      //      ^- cycle 1 -------------------------------------------^
      //
      // In the last step we used the fact that carry-less multiplication is bit-order agnostic:
      // rev(a cx b) = rev(a) cx rev(b).

      ///////////////
      // Butterfly //
      ///////////////

      // The butterfly / inverse butterfly network executing bcompress/bdecompress (zbe)
      // instructions. For bdecompress, the control bits mask of a local left region is generated
      // by the inverse of a n-bit left rotate and complement upon wrap (LROTC) operation by the
      // number of ones in the deposit bitmask to the right of the segment. n hereby denotes the
      // width of the according segment. The bitmask for a pertaining local right region is equal
      // to the corresponding local left region. Bcompress uses an analogue inverse process.
      // Consider the following 8-bit example.  For details, see Hilewitz et al. "Fast Bit Gather,
      // Bit Scatter and Bit Permuation Instructions for Commodity Microprocessors", (2008).
      //
      // The bcompress/bdecompress instructions are completed in 2 cycles. In the first cycle, the
      // control bitmask is prepared by executing the parallel prefix bit count. In the second
      // cycle, the bit swapping is executed according to the control masks.

      // 8-bit example:  (Hilewitz et al.)
      // Consider the instruction bdecompress operand_a_i deposit_mask
      // Let operand_a_i = 8'babcd_efgh
      //    deposit_mask = 8'b1010_1101
      //
      // control bitmask for stage 1:
      //  - number of ones in the right half of the deposit bitmask: 3
      //  - width of the segment: 4
      //  - control bitmask = ~LROTC(4'b0, 3)[3:0] = 4'b1000
      //
      // control bitmask:   c3 c2  c1 c0  c3 c2  c1 c0
      //                    1  0   0  0   1  0   0  0
      //                    <- L ----->   <- R ----->
      // operand_a_i        a  b   c  d   e  f   g  h
      //                    :\ |   |  |  /:  |   |  |
      //                    : +|---|--|-+ :  |   |  |
      //                    :/ |   |  |  \:  |   |  |
      // stage 1            e  b   c  d   a  f   g  h
      //                    <L->   <R->   <L->   <R->
      // control bitmask:   c3 c2  c3 c2  c1 c0  c1 c0
      //                    1  1   1  1   1  0   1  0
      //                    :\ :\ /: /:   :\ |  /:  |
      //                    : +:-+-:+ :   : +|-+ :  |
      //                    :/ :/ \: \:   :/ |  \:  |
      // stage 2            c  d   e  b   g  f   a  h
      //                    L  R   L  R   L  R   L  R
      // control bitmask:   c3 c3  c2 c2  c1 c1  c0 c0
      //                    1  1   0  0   1  1   0  0
      //                    :\/:   |  |   :\/:   |  |
      //                    :  :   |  |   :  :   |  |
      //                    :/\:   |  |   :/\:   |  |
      // stage 3            d  c   e  b   f  g   a  h
      // & deposit bitmask: 1  0   1  0   1  1   0  1
      // result:            d  0   e  0   f  g   0  h


    //////////////////////////////////////
    // Multicycle Bitmanip Instructions //
    //////////////////////////////////////
    // Ternary instructions + Shift Rotations + Bit Compress/Decompress + CRC
    // For ternary instructions (zbt), operand_a_i is tied to rs1 in the first cycle and rs3 in the
    // second cycle. operand_b_i is always tied to rs2.


  ////////////////
  // Result mux //
  ////////////////

endmodule
