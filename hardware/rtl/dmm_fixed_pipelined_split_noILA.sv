`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/18/2026 07:12:40 PM
// Design Name: 
// Module Name: dmm_fixed_pipelined_split_noILA
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dmm_fixed_pipelined_split_noILA 
    #(
        parameter integer width = 64,
        parameter integer FRAC = 48
    )
    (
    input clk, reset_n,
    input start_solving,
    output logic done,
    output logic [31:0] steps,
    input logic [31:0] dt, n, n_clause,
    
    input [31:0] bram1_dout_b, bram2_dout_b, bram3_dout_b,
    output logic bram_en_b,
    output logic [31:0] bram_addr_b
    
    );
    
    typedef logic signed [width-1:0] fxp_t;
    typedef logic signed [width*2-1:0] fxp_2t;
    logic signed [width-1:0] alpha, beta, delta, gamma, eps, zeta;
    logic signed [width-1:0] one, minus_one, half;
    logic [31:0] F_dt; // F + dt or dt is 2e-4, so 16 + 4
    assign F_dt = FRAC + dt;
    
    function automatic fxp_t fxp_from_real(input real x);
        longint signed tmp;
        tmp = longint'(x * (2.0**FRAC));
        return fxp_t'(tmp);
    endfunction
        
    assign alpha = fxp_from_real(5);
    assign beta = fxp_from_real(20);
    assign delta = fxp_from_real(0.25);
    assign gamma = fxp_from_real(0.05);
    assign eps = fxp_from_real(0.001);
    assign zeta = fxp_from_real(0.1);
//    assign dt = 6; // 2e-6
    assign one = fxp_from_real(1);
    assign minus_one = fxp_from_real(-1);
    assign half = fxp_from_real(0.5);
    
    logic [31:0] rd_addr, rd_addr_d1, rd_addr_d2, rd_addr_d3, rd_addr_d4, rd_addr_d5, rd_addr_d6;
    logic signed [width-1:0] dina_xl, dina_xs, doutb_xl, doutb_xs;
    logic enb, wea;
    blk_mem_gen_0 bram_xl (
      .clka(clk),    // input wire clka
      .ena(wea),
      .wea(wea),      // input wire [0 : 0] wea
      .addra(rd_addr_d6),  // input wire [31 : 0] addra
      .dina(dina_xl),    // input wire [width-1 : 0] dina
      .clkb(clk),    // input wire clkb
      .enb(enb),      // input wire enb
      .addrb(rd_addr),  // input wire [31 : 0] addrb
      .doutb(doutb_xl)  // output wire [width : 0] doutb
    );
    blk_mem_gen_1 bram_xs (
      .clka(clk),    // input wire clka
      .ena(wea),
      .wea(wea),      // input wire [0 : 0] wea
      .addra(rd_addr_d6),  // input wire [31 : 0] addra
      .dina(dina_xs),    // input wire [width-1 : 0] dina
      .clkb(clk),    // input wire clkb
      .enb(enb),      // input wire enb
      .addrb(rd_addr),  // input wire [31 : 0] addrb
      .doutb(doutb_xs)  // output wire [width-1 : 0] doutb
    );
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            rd_addr <= '0;
            rd_addr_d1 <= '0;
            rd_addr_d2 <= '0;
            rd_addr_d3 <= '0;
            rd_addr_d4 <= '0;
            rd_addr_d5 <= '0;
            rd_addr_d6 <= '0;
        end else begin
            rd_addr_d1 <= rd_addr;
            rd_addr_d2 <= rd_addr_d1;
            rd_addr_d3 <= rd_addr_d2;
            rd_addr_d4 <= rd_addr_d3;
            rd_addr_d5 <= rd_addr_d4;
            rd_addr_d6 <= rd_addr_d5;
            if (clause_counter > 6 && clause_counter < n_clause + 7) begin
                rd_addr <= clause_counter - 7;
            end else begin
                rd_addr <= '0;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            wea <= 0;
            enb <= 0;
        end else begin      
            if (clause_counter > 6 && clause_counter < n_clause + 8) begin
                enb <= 1;
            end else begin
                enb <= 0;
            end 
            if (clause_counter > 12 && clause_counter < n_clause + 13) begin
                wea <= 1;
            end else begin
                wea <= 0;
            end
        end
    end
    
    logic signed [width-1:0] new_v1, new_v2, new_v3;
    logic signed [width-1:0] G_n_1_full, G_n_2_full, G_n_3_full, R_n_full, G_R_full;
    
    logic [31:0] clause_counter;
    logic check_clauses;
    logic [31:0] check_out;
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            clause_counter <= 0;
            steps <= 0;
            check_out <= 0;
            bram_addr_b <= 0;
            bram_en_b <= 0;         
  
            
        end else begin
            if (start_solving) begin
                if (done == 0) begin
                    bram_en_b <= 1;
                    bram_addr_b <= clause_counter << 2;
                
                    if (clause_counter < n_clause+15) begin
                        clause_counter <= clause_counter + 1;                
                    end else begin
                        clause_counter <= 0;
                        steps <= steps + 1;
                    end
                end
                
                if (clause_counter > 8 && clause_counter < n_clause + 9) begin
                    check_out <= check_out + check_clauses;
                end else begin
                    check_out <= 0;
                end
            end else begin // if start_solving
                bram_en_b <= 0;
                bram_addr_b <= 0;
                clause_counter <= 0;
            end
        end // if reset
    end
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            done <= 0;
        end else begin
            if (check_out == n_clause && done == 0) begin
                done <= 1;
            end
        end
    end
    
// *****************************************************************************
// PIPELINE OVERVIEW
// *****************************************************************************
//
// Front-end / clause and variable fetch:
//
//   sA : Register raw clause BRAM outputs.
//        Captures bram1_dout_b, bram2_dout_b, bram3_dout_b.
//
//   sB : Decode packed clause words.
//        Extract variable indices and literal signs.
//
//   sC : Delay decoded indices/signs for alignment.
//
//   sD : Delay decoded indices/signs for alignment.
//        Used by the v reconstruction block.
//
//   sE : Final index/sign alignment before arithmetic stage 0.
//        Aligned with new_v1, new_v2, new_v3.
//
//   v reconstruction block:
//        Reads the active variable BRAM set, sums the three split components,
//        clamps the total v to [-1, 1], and applies the literal sign.
//        Produces new_v1, new_v2, new_v3.
//
// Main arithmetic pipeline:
//
//   Stage 0 : Sort/order the three clause literals.
//             Finds largest, second largest, and third largest signed values,
//             together with their signs and variable indices.
//
//   Stage 1 : Compute clause-level quantities.
//             Computes C_m, G_n_1, G_n_2, G_n_3, R_n,
//             and check_clauses.
//
//   Stage 2 : Prepare multiplier inputs.
//             Computes C_m - delta, C_m - gamma, x_s + eps,
//             1 - x_s, 1 + zeta*x_l, and applies dt shifts to G/R.
//
//   Stage 3 : Multiplier group A.
//             Computes alpha*(C_m-delta), beta*(x_s+eps),
//             x_l*x_s, and (1+zeta*x_l)*(1-x_s).
//
//   Stage 4 : Postprocess multiplier group A.
//             Applies fixed-point shifts/truncation and prepares factors
//             for the second multiplier group.
//
//   Stage 5 : Multiplier group B.
//             Computes x_s update product, G terms times x_l*x_s,
//             and R term times the rigidity factor.
//
//   Stage 6 : Final shifts and memory-variable updates.
//             Produces full G/R contributions, G_R_full,
//             and updated/clamped x_l and x_s write data.
//
//   Stage 7 : Final index delay.
//             Delays variable indices to align with accumulator writeback.
//
// Writeback / accumulator:
//
//   WB : Read old accumulated split-v values, handle tag/collision cases,
//        add the new G/R contributions, and register va_add_new,
//        vb_add_new, vc_add_new for writing into the inactive ping-pong BRAM set.
//
// *****************************************************************************
        
    logic [31:0] sA_bram1, sA_bram2, sA_bram3;
    logic        sA_valid;
    
    always_ff @(posedge clk) begin
      if (!reset_n) begin
        sA_bram1 <= '0;
        sA_bram2 <= '0;
        sA_bram3 <= '0;
        sA_valid <= 1'b0;
      end else begin
        sA_bram1 <= bram1_dout_b;
        sA_bram2 <= bram2_dout_b;
        sA_bram3 <= bram3_dout_b;
        sA_valid <= (bram_addr_b < (n_clause+1) << 2);
      end
    end
    
    logic [31:0] sB_v1_index, sB_v2_index, sB_v3_index;
    logic sB_v1_sign,  sB_v2_sign,  sB_v3_sign;
    logic [31:0] sC_v1_index, sC_v2_index, sC_v3_index;
    logic sC_v1_sign,  sC_v2_sign,  sC_v3_sign;
    logic [31:0] sD_v1_index, sD_v2_index, sD_v3_index;
    logic sD_v1_sign,  sD_v2_sign,  sD_v3_sign;
    logic [31:0] sE_v1_index, sE_v2_index, sE_v3_index;
    logic sE_v1_sign,  sE_v2_sign,  sE_v3_sign;
    
    always_ff @(posedge clk) begin
      if (!reset_n) begin
        sB_v1_index <= '0; 
        sB_v2_index <= '0; 
        sB_v3_index <= '0;
        sB_v1_sign <= 1'b0; 
        sB_v2_sign <= 1'b0; 
        sB_v3_sign <= 1'b0;
      end else begin
        sB_v1_index <= sA_valid ? sA_bram1[31:1] : 31'd0;
        sB_v2_index <= sA_valid ? sA_bram2[31:1] : 31'd0;
        sB_v3_index <= sA_valid ? sA_bram3[31:1] : 31'd0;
        sB_v1_sign  <= sA_valid ? sA_bram1[0] : 1'b0;
        sB_v2_sign  <= sA_valid ? sA_bram2[0] : 1'b0;
        sB_v3_sign  <= sA_valid ? sA_bram3[0] : 1'b0;
      end
    end

    always_ff @(posedge clk) begin
      if (!reset_n) begin
        sC_v1_index <= '0;
        sC_v2_index <= '0;
        sC_v3_index <= '0;
        sC_v1_sign <= 0;
        sC_v2_sign <= 0;
        sC_v3_sign <= 0;
        sD_v1_index <= '0;
        sD_v2_index <= '0;
        sD_v3_index <= '0;
        sD_v1_sign <= 0;
        sD_v2_sign <= 0;
        sD_v3_sign <= 0;
        sE_v1_index <= '0;
        sE_v2_index <= '0;
        sE_v3_index <= '0;
        sE_v1_sign <= 0;
        sE_v2_sign <= 0;
        sE_v3_sign <= 0;
      end else begin
        sC_v1_index <= sB_v1_index;
        sC_v2_index <= sB_v2_index;
        sC_v3_index <= sB_v3_index;
        sC_v1_sign <= sB_v1_sign;
        sC_v2_sign <= sB_v2_sign;
        sC_v3_sign <= sB_v3_sign;
        sD_v1_index <= sC_v1_index;
        sD_v2_index <= sC_v2_index;
        sD_v3_index <= sC_v3_index;
        sD_v1_sign <= sC_v1_sign;
        sD_v2_sign <= sC_v2_sign;
        sD_v3_sign <= sC_v3_sign;
        sE_v1_index <= sD_v1_index;
        sE_v2_index <= sD_v2_index;
        sE_v3_index <= sD_v3_index;
        sE_v1_sign <= sD_v1_sign;
        sE_v2_sign <= sD_v2_sign;
        sE_v3_sign <= sD_v3_sign;      
      end
    end
    
    
    
    
    // stage 0 - no mul max_v, max_q
    logic signed [width-1:0] s0_max_v, s0_max_v_2, s0_max_v_3;
    logic s0_max_q, s0_max_q_2, s0_max_q_3;
    logic [15:0] s0_max_v_index_1, s0_max_v_index_2, s0_max_v_index_3;
    
    // stage 1 - no mul
    logic signed [width-1:0] s1_G_n_1, s1_G_n_2, s1_G_n_3, s1_R_n, s1_C_m;    
    logic [15:0] s1_max_v_index_1, s1_max_v_index_2, s1_max_v_index_3;
    
    // stage 2 - no mul, build mul
    logic signed [width-1:0] s2_d_cm_delta, s2_d_xs_eps, s2_d_cm_gamma, s2_one_minus_xs;
    logic signed [width-1:0] s2_G_n_1, s2_G_n_2, s2_G_n_3, s2_R_n;
    logic signed [width-1:0] s2_qwe6;
    
    logic [15:0] s2_max_v_index_1, s2_max_v_index_2, s2_max_v_index_3;
    logic signed [width-1:0] s2_x_l_current, s2_x_s_current;
    
    // stage 3 mul A
    logic signed [width*2-1:0] s3_mul_alpha; // alpha * (C_m - delta)
    logic signed [width*2-1:0] s3_mul_beta; // beta * (x_s + eps)
    logic signed [width*2-1:0] s3_mul_xlxs; // x_l * x_s
    logic signed [width-1:0] s3_d_cm_gamma;
    
    logic [15:0] s3_max_v_index_1, s3_max_v_index_2, s3_max_v_index_3;
    logic signed [width-1:0] s3_G_n_1, s3_G_n_2, s3_G_n_3, s3_R_n;
    logic signed [width*2-1:0] s3_qwe7;
    
    logic signed [width-1:0] s3_x_l_current, s3_x_s_current;
  
    // stage 4 no mul, postprocess A + prep B
    
    logic signed [width-1:0] s4_funct_x_l;
    logic signed [width-1:0] s4_funct_x_s_1;
    logic signed [width-1:0] s4_qwe2, s4_qwe7;
    logic signed [width-1:0] s4_d_cm_gamma;
    logic signed [width-1:0] s4_G_n_1, s4_G_n_2, s4_G_n_3, s4_R_n;
    logic [15:0] s4_max_v_index_1, s4_max_v_index_2, s4_max_v_index_3;
    
    logic signed [width-1:0] s4_x_l_current, s4_x_s_current;
    // stage 5 mul B
    
    logic signed [width*2-1:0] s5_mul_funct_x_s; // funct_x_s_1 * (C_m - gamma)
    logic signed [width*2-1:0] s5_mul_G_n_1, s5_mul_G_n_2, s5_mul_G_n_3; // G * qwe2
    logic signed [width*2-1:0] s5_mul_R_n;
    logic signed [width-1:0] s5_funct_x_l;
    logic [15:0] s5_max_v_index_1, s5_max_v_index_2, s5_max_v_index_3;
    logic signed [width-1:0] s5_x_l_current, s5_x_s_current;
    
    // stage 6 final outputs
    
    logic [15:0] s6_max_v_index_1, s6_max_v_index_2, s6_max_v_index_3;
    
    // stage 7 max_v_index for all_full_Gs_temp
    
    logic [15:0] s7_max_v_index_1, s7_max_v_index_2, s7_max_v_index_3;
    
    //////////////////////////////////////////////////////////////////////////////////////////////
    
    
    // stage 0
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            s0_max_v <= '0;
            s0_max_v_2 <= '0;
            s0_max_v_3 <= '0;
            s0_max_q <= 0;
            s0_max_q_2 <= 0;
            s0_max_q_3 <= 0;
            s0_max_v_index_1 <= '0;
            s0_max_v_index_2 <= '0;
            s0_max_v_index_3 <= '0;
        end else begin   
                if (new_v1 >= new_v2 && new_v1 >= new_v3) begin
                    s0_max_v <= new_v1;
                    s0_max_v_2 <= (new_v2 >= new_v3) ? new_v2 : new_v3;
                    s0_max_v_3 <= (new_v2 >= new_v3) ? new_v3 : new_v2;
                    s0_max_q <= sE_v1_sign;
                    s0_max_q_2 <= (new_v2 >= new_v3) ? sE_v2_sign : sE_v3_sign;
                    s0_max_q_3 <= (new_v2 >= new_v3) ? sE_v3_sign : sE_v2_sign;
                    s0_max_v_index_1 <= sE_v1_index;
                    s0_max_v_index_2 <= (new_v2 >= new_v3) ? sE_v2_index : sE_v3_index;
                    s0_max_v_index_3 <= (new_v2 >= new_v3) ? sE_v3_index : sE_v2_index;
                end else if (new_v2 >= new_v1 && new_v2 >= new_v3) begin
                    s0_max_v <= new_v2;
                    s0_max_v_2 <= (new_v1 >= new_v3) ? new_v1 : new_v3;
                    s0_max_v_3 <= (new_v1 >= new_v3) ? new_v3 : new_v1;
                    s0_max_q <= sE_v2_sign;
                    s0_max_q_2 <= (new_v1 >= new_v3) ? sE_v1_sign : sE_v3_sign;
                    s0_max_q_3 <= (new_v1 >= new_v3) ? sE_v3_sign : sE_v1_sign;
                    s0_max_v_index_1 <= sE_v2_index;
                    s0_max_v_index_2 <= (new_v1 >= new_v3) ? sE_v1_index : sE_v3_index;
                    s0_max_v_index_3 <= (new_v1 >= new_v3) ? sE_v3_index : sE_v1_index;
                end else if (new_v3 >= new_v1 && new_v3 >= new_v2) begin
                    s0_max_v <= new_v3;
                    s0_max_v_2 <= (new_v1 >= new_v2) ? new_v1 : new_v2;
                    s0_max_v_3 <= (new_v1 >= new_v2) ? new_v2 : new_v1;
                    s0_max_q <= sE_v3_sign;
                    s0_max_q_2 <= (new_v1 >= new_v2) ? sE_v1_sign : sE_v2_sign;
                    s0_max_q_3 <= (new_v1 >= new_v2) ? sE_v2_sign : sE_v1_sign;
                    s0_max_v_index_1 <= sE_v3_index;
                    s0_max_v_index_2 <= (new_v1 >= new_v2) ? sE_v1_index : sE_v2_index;
                    s0_max_v_index_3 <= (new_v1 >= new_v2) ? sE_v2_index : sE_v1_index;
                end else begin
                    s0_max_v <= new_v1;
                    s0_max_v_2 <= new_v2;
                    s0_max_v_3 <= new_v3;
                    s0_max_q <= sE_v1_sign;
                    s0_max_q_2 <= sE_v2_sign;
                    s0_max_q_3 <= sE_v3_sign;
                    s0_max_v_index_1 <= sE_v1_index;
                    s0_max_v_index_2 <= sE_v2_index;
                    s0_max_v_index_3 <= sE_v3_index;
                end      
        end // if reset
    end
    
    // stage 1
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            s1_G_n_1 <= '0;
            s1_G_n_2 <= '0;
            s1_G_n_3 <= '0;
            s1_R_n <= '0;
            s1_C_m <= '0;
            check_clauses <= 0;
            s1_max_v_index_1 <= '0;
            s1_max_v_index_2 <= '0;
            s1_max_v_index_3 <= '0;
        end else begin
            fxp_t max_v_real, max_q_real, inv_max_vv, inv_max_vv_2;
            max_v_real = (s0_max_q == 1'b0) ? s0_max_v : -s0_max_v;
            max_q_real = (s0_max_q == 0) ? fxp_from_real(1) : fxp_from_real(-1);
            s1_R_n <= (max_q_real - max_v_real) >>> 1;
        
            inv_max_vv = (one-s0_max_v) >>> 1;
            s1_G_n_2 <= (s0_max_q_2 == 0) ? inv_max_vv : -inv_max_vv;
            s1_G_n_3 <= (s0_max_q_3 == 0) ? inv_max_vv : -inv_max_vv;
            inv_max_vv_2 = (one-s0_max_v_2) >>> 1;
            s1_G_n_1 <= (s0_max_q == 0) ? inv_max_vv_2 : -inv_max_vv_2;
            s1_C_m <= inv_max_vv;
            
            check_clauses <= (inv_max_vv < half);
            s1_max_v_index_1 <= s0_max_v_index_1;
            s1_max_v_index_2 <= s0_max_v_index_2;
            s1_max_v_index_3 <= s0_max_v_index_3;
        end
    end
    
    // stage 2
    
    always_ff @(posedge clk) begin
    fxp_t qwe6_trunc;
    fxp_2t qwe6_tmp;
        if (!reset_n) begin
            s2_d_cm_delta <= '0;
            s2_d_xs_eps <= '0;
            s2_d_cm_gamma <= '0;
            s2_one_minus_xs <= '0;
            s2_R_n <= '0;
            s2_G_n_1 <= '0;
            s2_G_n_2 <= '0;
            s2_G_n_3 <= '0;
            s2_x_l_current <= '0;
            s2_x_s_current <= '0;
            s2_qwe6 <= '0;
            s2_max_v_index_1 <= '0;
            s2_max_v_index_2 <= '0;
            s2_max_v_index_3 <= '0;
        end else begin
            s2_d_cm_delta <= s1_C_m - delta;
            s2_d_cm_gamma <= s1_C_m - gamma;
            
            s2_d_xs_eps <= doutb_xs + eps;            
            s2_one_minus_xs <= one - doutb_xs;
            qwe6_tmp = (doutb_xl * zeta) >>> FRAC;
            qwe6_trunc = qwe6_tmp[width-1:0];
            s2_qwe6 <= one + qwe6_trunc;
            
            s2_x_l_current <= doutb_xl;
            s2_x_s_current <= doutb_xs;
            
            s2_R_n <= s1_R_n >>> dt;
            s2_G_n_1 <= s1_G_n_1 >>> dt;
            s2_G_n_2 <= s1_G_n_2 >>> dt;
            s2_G_n_3 <= s1_G_n_3 >>> dt;
            s2_max_v_index_1 <= s1_max_v_index_1;
            s2_max_v_index_2 <= s1_max_v_index_2;
            s2_max_v_index_3 <= s1_max_v_index_3;       
        end
    end
    
    // stage 3 MUL A
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            s3_mul_alpha <= '0;
            s3_mul_beta <= '0;
            s3_mul_xlxs <= '0;
            s3_qwe7 <= '0;
            s3_d_cm_gamma <= '0;
            s3_R_n <= '0;
            s3_G_n_1 <= '0;
            s3_G_n_2 <= '0;
            s3_G_n_3 <= '0;
            s3_max_v_index_1 <= '0;
            s3_max_v_index_2 <= '0;
            s3_max_v_index_3 <= '0;
            s3_x_l_current <= '0;
            s3_x_s_current <= '0;
        end else begin
            s3_mul_alpha <= alpha * s2_d_cm_delta;
            s3_mul_beta <= beta * s2_d_xs_eps;
            s3_mul_xlxs <= s2_x_l_current * s2_x_s_current;
            s3_qwe7 <= s2_qwe6 * s2_one_minus_xs;
            
            s3_d_cm_gamma <= s2_d_cm_gamma;
            
            s3_R_n <= s2_R_n;
            s3_G_n_1 <= s2_G_n_1;
            s3_G_n_2 <= s2_G_n_2;
            s3_G_n_3 <= s2_G_n_3;
            s3_x_l_current <= s2_x_l_current;
            s3_x_s_current <= s2_x_s_current;
            s3_max_v_index_1 <= s2_max_v_index_1;
            s3_max_v_index_2 <= s2_max_v_index_2;
            s3_max_v_index_3 <= s2_max_v_index_3;
        end
    end
    
    
    // stage 4
    
    
    always_ff @(posedge clk) begin
    fxp_2t s4_funct_x_l_48b, s4_funct_x_s_1_48b, s4_qwe2_48b, s4_qwe7_48b;
        if (!reset_n) begin
            s4_funct_x_l <= '0;
            s4_funct_x_s_1 <= '0;
            s4_qwe2 <= '0;
            s4_qwe7 <= '0;
            s4_R_n <= '0;
            s4_G_n_1 <= '0;
            s4_G_n_2 <= '0;
            s4_G_n_3 <= '0;
            s4_d_cm_gamma <= '0;
            s4_max_v_index_1 <= '0;
            s4_max_v_index_2 <= '0;
            s4_max_v_index_3 <= '0;
            s4_x_l_current <= '0;
            s4_x_s_current <= '0;
        end else begin
            s4_funct_x_l_48b = s3_mul_alpha >>> F_dt;
            s4_funct_x_l <= s4_funct_x_l_48b[width-1:0];
            s4_funct_x_s_1_48b = s3_mul_beta >>> FRAC;
            s4_funct_x_s_1 <= s4_funct_x_s_1_48b[width-1:0];
            s4_qwe2_48b = (s3_mul_xlxs >>> FRAC);
            s4_qwe2 <= s4_qwe2_48b[width-1:0];
 
            s4_qwe7_48b = s3_qwe7 >>> FRAC;
            s4_qwe7 <= s4_qwe7_48b[width-1:0];
            
            s4_d_cm_gamma <= s3_d_cm_gamma;
            s4_R_n <= s3_R_n;
            s4_G_n_1 <= s3_G_n_1;
            s4_G_n_2 <= s3_G_n_2;
            s4_G_n_3 <= s3_G_n_3;
            s4_x_l_current <= s3_x_l_current;
            s4_x_s_current <= s3_x_s_current;
            s4_max_v_index_1 <= s3_max_v_index_1;
            s4_max_v_index_2 <= s3_max_v_index_2;
            s4_max_v_index_3 <= s3_max_v_index_3;
        end
    end
    
    // stage 5 MUL B
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            s5_mul_funct_x_s <= '0;
            s5_mul_G_n_1 <= '0;
            s5_mul_G_n_2 <= '0;
            s5_mul_G_n_3 <= '0;
            s5_mul_R_n <= '0;
            s5_max_v_index_1 <= '0;
            s5_max_v_index_2 <= '0;
            s5_max_v_index_3 <= '0;
            s5_x_l_current <= '0;
            s5_x_s_current <= '0;
            s5_funct_x_l <= '0;
            
        end else begin
            s5_mul_funct_x_s <= s4_funct_x_s_1 * s4_d_cm_gamma;
            
            s5_mul_G_n_1 <= s4_G_n_1 * s4_qwe2;
            s5_mul_G_n_2 <= s4_G_n_2 * s4_qwe2;
            s5_mul_G_n_3 <= s4_G_n_3 * s4_qwe2;
            s5_mul_R_n <= s4_R_n * s4_qwe7;
            
            s5_funct_x_l <= s4_funct_x_l;
            s5_max_v_index_1 <= s4_max_v_index_1;
            s5_max_v_index_2 <= s4_max_v_index_2;
            s5_max_v_index_3 <= s4_max_v_index_3;
            s5_x_l_current <= s4_x_l_current;
            s5_x_s_current <= s4_x_s_current;
            
        end
    end 
    
    // stage 6 final shifts and sums. no mul
    
    always_ff @(posedge clk) begin
    fxp_2t G_n_1_full_48b, G_n_2_full_48b, G_n_3_full_48b, R_n_full_48b, funct_x_s_48b; 
    fxp_t funct_x_l, funct_x_s;
        if (!reset_n) begin
            G_n_1_full <= '0;
            G_n_2_full <= '0;
            G_n_3_full <= '0;
            R_n_full <= '0;
            G_R_full <= '0;
            s6_max_v_index_1 <= '0;
            s6_max_v_index_2 <= '0;
            s6_max_v_index_3 <= '0;
            
            dina_xl <= '0;
            dina_xs <= '0;
        end else begin
            logic signed [width-1:0] tmp_xl, tmp_xs;
        
            funct_x_l = s5_funct_x_l;
            funct_x_s_48b = s5_mul_funct_x_s >>> F_dt;
            funct_x_s = funct_x_s_48b[width-1:0];
            
            G_n_1_full_48b = s5_mul_G_n_1 >>> FRAC;
            G_n_1_full = G_n_1_full_48b[width-1:0];
            G_n_2_full_48b = s5_mul_G_n_2 >>> FRAC;
            G_n_2_full <= G_n_2_full_48b[width-1:0];
            G_n_3_full_48b = s5_mul_G_n_3 >>> FRAC;
            G_n_3_full <= G_n_3_full_48b[width-1:0];
            R_n_full_48b = s5_mul_R_n >>> FRAC;
            R_n_full = R_n_full_48b[width-1:0];
            G_R_full <= G_n_1_full + R_n_full; // G_n_1_full and R_n_full sequential to feed into G_R_full
            
            s6_max_v_index_1 <= s5_max_v_index_1;
            s6_max_v_index_2 <= s5_max_v_index_2;
            s6_max_v_index_3 <= s5_max_v_index_3;
            
            tmp_xl = s5_x_l_current + funct_x_l;
            tmp_xs = s5_x_s_current + funct_x_s;
            dina_xl <= (tmp_xl > one) ? tmp_xl : one;
            dina_xs <= (tmp_xs < '0) ? '0 : (tmp_xs > one) ? one : tmp_xs;
        end
    end
    
    // stage 7 extra delays
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            s7_max_v_index_1 <= '0;
            s7_max_v_index_2 <= '0;
            s7_max_v_index_3 <= '0;
        end else begin
            s7_max_v_index_1 <= s6_max_v_index_1;
            s7_max_v_index_2 <= s6_max_v_index_2;
            s7_max_v_index_3 <= s6_max_v_index_3;       
        end
    end

    logic signed [width-1:0] v1a_doutb, v1b_doutb, v1c_doutb; 
    logic signed [width-1:0] v2a_doutb, v2b_doutb, v2c_doutb;
    logic signed [width-1:0] v3a_doutb, v3b_doutb, v3c_doutb;
    logic signed [width-1:0] v1_total, v2_total, v3_total;
    
    always_ff @(posedge clk) begin  
    logic signed [width-1:0] v1_total_tmp, v2_total_tmp, v3_total_tmp;  
        if (!reset_n) begin  
            v1_total <= '0;
            v2_total <= '0;
            v3_total <= '0;
            new_v1 <= '0;
            new_v2 <= '0;
            new_v3 <= '0;
        end else begin
            if (start_solving) begin         
                v1_total <= v1a_doutb + v1b_doutb + v1c_doutb;
                v2_total <= v2a_doutb + v2b_doutb + v2c_doutb;
                v3_total <= v3a_doutb + v3b_doutb + v3c_doutb;
                v1_total_tmp = (v1_total > one) ? one : (v1_total < minus_one) ? minus_one : v1_total;
                v2_total_tmp = (v2_total > one) ? one : (v2_total < minus_one) ? minus_one : v2_total;
                v3_total_tmp = (v3_total > one) ? one : (v3_total < minus_one) ? minus_one : v3_total;
                new_v1 <= (sD_v1_sign) ? -v1_total_tmp : v1_total_tmp;
                new_v2 <= (sD_v2_sign) ? -v2_total_tmp : v2_total_tmp;
                new_v3 <= (sD_v3_sign) ? -v3_total_tmp : v3_total_tmp;                
            end else begin // start_solving
                v1_total <= '0;
                v2_total <= '0;
                v3_total <= '0;
                new_v1 <= '0;
                new_v2 <= '0;
                new_v3 <= '0;
            end
        end // reset
    end
 
    
    logic ena_bram1, ena_bram2, wea_bram1, wea_bram2, enb_bram1, enb_bram2;
    logic choose_bram;
    assign choose_bram = steps[0]; // even steps - 0, odd steps - 1
    logic wea_tag, enb_tag;
    always_ff @(posedge clk) begin // en, we
        if (!reset_n) begin
            ena_bram1 <= 0;
            wea_bram1 <= 0;
            enb_bram1 <= 0;
            ena_bram2 <= 0;
            wea_bram2 <= 0;
            enb_bram2 <= 0;
            
            enb_tag <= 0;
            wea_tag <= 0;
        end else begin
            if (start_solving) begin
                if (!choose_bram) begin // even steps
                    if (clause_counter > 2 && clause_counter < n_clause + 14) begin
                        ena_bram1 <= 1;
                    end else begin
                        ena_bram1 <= 0;
                    end
                    if (clause_counter > 11 && clause_counter < n_clause + 14) begin 
                        enb_bram1 <= 1;
                        enb_bram2 <= 1;
                    end else begin
                        enb_bram1 <= 0;
                        enb_bram2 <= 0;
                    end
                    if (clause_counter > 13 && clause_counter < n_clause + 14) begin // even steps write into bram2
                        ena_bram2 <= 1;
                        wea_bram2 <= 1;
                    end else begin
                        ena_bram2 <= 0;
                        wea_bram2 <= 0;
                    end
                end else begin // odd steps
                    if (clause_counter > 2 && clause_counter < n_clause + 14) begin
                        ena_bram2 <= 1;
                    end else begin
                        ena_bram2 <= 0;
                    end
                    if (clause_counter > 11 && clause_counter < n_clause + 14) begin
                        enb_bram2 <= 1;
                        enb_bram1 <= 1;
                      //  wea_bram1
                    end else begin
                        enb_bram2 <= 0;
                        enb_bram1 <= 0;
                    end
                    if (clause_counter > 13 && clause_counter < n_clause + 14) begin // odd steps write into bram1
                        ena_bram1 <= 1;
                        wea_bram1 <= 1;
                    end else begin
                        ena_bram1 <= 0;
                        wea_bram1 <= 0;
                    end
                end
                if (clause_counter > 11 && clause_counter < n_clause + 13) begin
                    enb_tag <= 1;
                end else begin
                    enb_tag <= 0;
                end
                if (clause_counter > 12 && clause_counter < n_clause + 12) begin
                    wea_tag <= 1;
                end else begin
                    wea_tag <= 0;
                end
            end // start_solving
        end
    end
    
    logic signed [width-1:0] douta_bram1_v1a, dina_bram1_v1a, doutb_bram1_v1a, dinb_bram1_v1a;
    logic signed [width-1:0] douta_bram1_v1b, dina_bram1_v1b, doutb_bram1_v1b, dinb_bram1_v1b;
    logic signed [width-1:0] douta_bram1_v1c, dina_bram1_v1c, doutb_bram1_v1c, dinb_bram1_v1c;
    logic signed [width-1:0] douta_bram1_v2a, dina_bram1_v2a, doutb_bram1_v2a, dinb_bram1_v2a;
    logic signed [width-1:0] douta_bram1_v2b, dina_bram1_v2b, doutb_bram1_v2b, dinb_bram1_v2b;
    logic signed [width-1:0] douta_bram1_v2c, dina_bram1_v2c, doutb_bram1_v2c, dinb_bram1_v2c;
    logic signed [width-1:0] douta_bram1_v3a, dina_bram1_v3a, doutb_bram1_v3a, dinb_bram1_v3a;
    logic signed [width-1:0] douta_bram1_v3b, dina_bram1_v3b, doutb_bram1_v3b, dinb_bram1_v3b;
    logic signed [width-1:0] douta_bram1_v3c, dina_bram1_v3c, doutb_bram1_v3c, dinb_bram1_v3c;
    logic signed [width-1:0] douta_bram2_v1a, dina_bram2_v1a, doutb_bram2_v1a, dinb_bram2_v1a;
    logic signed [width-1:0] douta_bram2_v1b, dina_bram2_v1b, doutb_bram2_v1b, dinb_bram2_v1b;
    logic signed [width-1:0] douta_bram2_v1c, dina_bram2_v1c, doutb_bram2_v1c, dinb_bram2_v1c;
    logic signed [width-1:0] douta_bram2_v2a, dina_bram2_v2a, doutb_bram2_v2a, dinb_bram2_v2a;
    logic signed [width-1:0] douta_bram2_v2b, dina_bram2_v2b, doutb_bram2_v2b, dinb_bram2_v2b;
    logic signed [width-1:0] douta_bram2_v2c, dina_bram2_v2c, doutb_bram2_v2c, dinb_bram2_v2c;
    logic signed [width-1:0] douta_bram2_v3a, dina_bram2_v3a, doutb_bram2_v3a, dinb_bram2_v3a;
    logic signed [width-1:0] douta_bram2_v3b, dina_bram2_v3b, doutb_bram2_v3b, dinb_bram2_v3b;
    logic signed [width-1:0] douta_bram2_v3c, dina_bram2_v3c, doutb_bram2_v3c, dinb_bram2_v3c;
    logic [15:0] addra_bram1_v1a, addrb_bram1_v1a;
    logic [15:0] addra_bram1_v1b, addrb_bram1_v1b;
    logic [15:0] addra_bram1_v1c, addrb_bram1_v1c;
    logic [15:0] addra_bram1_v2a, addrb_bram1_v2a;
    logic [15:0] addra_bram1_v2b, addrb_bram1_v2b;
    logic [15:0] addra_bram1_v2c, addrb_bram1_v2c;
    logic [15:0] addra_bram1_v3a, addrb_bram1_v3a;
    logic [15:0] addra_bram1_v3b, addrb_bram1_v3b;
    logic [15:0] addra_bram1_v3c, addrb_bram1_v3c;
    logic [15:0] addra_bram2_v1a, addrb_bram2_v1a;
    logic [15:0] addra_bram2_v1b, addrb_bram2_v1b;
    logic [15:0] addra_bram2_v1c, addrb_bram2_v1c;
    logic [15:0] addra_bram2_v2a, addrb_bram2_v2a;
    logic [15:0] addra_bram2_v2b, addrb_bram2_v2b;
    logic [15:0] addra_bram2_v2c, addrb_bram2_v2c;
    logic [15:0] addra_bram2_v3a, addrb_bram2_v3a;
    logic [15:0] addra_bram2_v3b, addrb_bram2_v3b;
    logic [15:0] addra_bram2_v3c, addrb_bram2_v3c;
    logic signed [width-1:0] va_add, vb_add, vc_add;
    
    
    always_comb begin // setting up all addresses
        if (!choose_bram) begin // even steps
            if (ena_bram1 && !wea_bram1) begin // read initial values from bram1 to compute v_total
                addra_bram1_v1a = sB_v1_index;
                addra_bram1_v1b = sB_v1_index;
                addra_bram1_v1c = sB_v1_index;
                addra_bram1_v2a = sB_v2_index;
                addra_bram1_v2b = sB_v2_index;
                addra_bram1_v2c = sB_v2_index;
                addra_bram1_v3a = sB_v3_index;
                addra_bram1_v3b = sB_v3_index;
                addra_bram1_v3c = sB_v3_index;
            end else begin
                addra_bram1_v1a = '0;
                addra_bram1_v1b = '0;
                addra_bram1_v1c = '0;
                addra_bram1_v2a = '0;
                addra_bram1_v2b = '0;
                addra_bram1_v2c = '0;
                addra_bram1_v3a = '0;
                addra_bram1_v3b = '0;
                addra_bram1_v3c = '0;
            end
            if (ena_bram2 && wea_bram2) begin // write new values into bram2 for addition
                addra_bram2_v1a = s7_max_v_index_1;
                addra_bram2_v1b = s7_max_v_index_2;
                addra_bram2_v1c = s7_max_v_index_3;
                addra_bram2_v2a = s7_max_v_index_1;
                addra_bram2_v2b = s7_max_v_index_2;
                addra_bram2_v2c = s7_max_v_index_3;
                addra_bram2_v3a = s7_max_v_index_1;
                addra_bram2_v3b = s7_max_v_index_2;
                addra_bram2_v3c = s7_max_v_index_3;
            end else begin
                addra_bram2_v1a = '0;
                addra_bram2_v1b = '0;
                addra_bram2_v1c = '0;
                addra_bram2_v2a = '0;
                addra_bram2_v2b = '0;
                addra_bram2_v2c = '0;
                addra_bram2_v3a = '0;
                addra_bram2_v3b = '0;
                addra_bram2_v3c = '0;
            end
        end else begin
            if (ena_bram2 && !wea_bram2) begin // read initial values from bram2 to compute v_total
                addra_bram2_v1a = sB_v1_index;
                addra_bram2_v1b = sB_v1_index;
                addra_bram2_v1c = sB_v1_index;
                addra_bram2_v2a = sB_v2_index;
                addra_bram2_v2b = sB_v2_index;
                addra_bram2_v2c = sB_v2_index;
                addra_bram2_v3a = sB_v3_index;
                addra_bram2_v3b = sB_v3_index;
                addra_bram2_v3c = sB_v3_index;
            end else begin
                addra_bram2_v1a = '0;
                addra_bram2_v1b = '0;
                addra_bram2_v1c = '0;
                addra_bram2_v2a = '0;
                addra_bram2_v2b = '0;
                addra_bram2_v2c = '0;
                addra_bram2_v3a = '0;
                addra_bram2_v3b = '0;
                addra_bram2_v3c = '0;
            end
            if (ena_bram1 && wea_bram1) begin // write new values into bram1 for addition
                addra_bram1_v1a = s7_max_v_index_1;
                addra_bram1_v1b = s7_max_v_index_2;
                addra_bram1_v1c = s7_max_v_index_3;
                addra_bram1_v2a = s7_max_v_index_1;
                addra_bram1_v2b = s7_max_v_index_2;
                addra_bram1_v2c = s7_max_v_index_3;
                addra_bram1_v3a = s7_max_v_index_1;
                addra_bram1_v3b = s7_max_v_index_2;
                addra_bram1_v3c = s7_max_v_index_3;
            end else begin
                addra_bram1_v1a = '0;
                addra_bram1_v1b = '0;
                addra_bram1_v1c = '0;
                addra_bram1_v2a = '0;
                addra_bram1_v2b = '0;
                addra_bram1_v2c = '0;
                addra_bram1_v3a = '0;
                addra_bram1_v3b = '0;
                addra_bram1_v3c = '0;
            end
        end
  
        if (ena_bram1 && !wea_bram1) begin
            v1a_doutb = douta_bram1_v1a;
            v2a_doutb = douta_bram1_v2a;
            v3a_doutb = douta_bram1_v3a;
            v1b_doutb = douta_bram1_v1b;
            v2b_doutb = douta_bram1_v2b;
            v3b_doutb = douta_bram1_v3b;
            v1c_doutb = douta_bram1_v1c;
            v2c_doutb = douta_bram1_v2c;
            v3c_doutb = douta_bram1_v3c;
        end else if (ena_bram2 && !wea_bram2) begin
            v1a_doutb = douta_bram2_v1a;
            v2a_doutb = douta_bram2_v2a;
            v3a_doutb = douta_bram2_v3a;
            v1b_doutb = douta_bram2_v1b;
            v2b_doutb = douta_bram2_v2b;
            v3b_doutb = douta_bram2_v3b;
            v1c_doutb = douta_bram2_v1c;
            v2c_doutb = douta_bram2_v2c;
            v3c_doutb = douta_bram2_v3c;
        end else begin
            v1a_doutb = '0;
            v2a_doutb = '0;
            v3a_doutb = '0;
            v1b_doutb = '0;
            v2b_doutb = '0;
            v3b_doutb = '0;
            v1c_doutb = '0;
            v2c_doutb = '0;
            v3c_doutb = '0;
        end
        
        // reading from both brams. depending on corresponding tag, choose which value to use for addition
        if (enb_bram1) begin // reading from bram1 for addition
            addrb_bram1_v1a = s5_max_v_index_1;
            addrb_bram1_v2a = s5_max_v_index_1;
            addrb_bram1_v3a = s5_max_v_index_1;
            addrb_bram1_v1b = s5_max_v_index_2;
            addrb_bram1_v2b = s5_max_v_index_2;
            addrb_bram1_v3b = s5_max_v_index_2;
            addrb_bram1_v1c = s5_max_v_index_3;
            addrb_bram1_v2c = s5_max_v_index_3;
            addrb_bram1_v3c = s5_max_v_index_3;
        end else begin
            addrb_bram1_v1a = '0;
            addrb_bram1_v2a = '0;
            addrb_bram1_v3a = '0;
            addrb_bram1_v1b = '0;
            addrb_bram1_v2b = '0;
            addrb_bram1_v3b = '0;
            addrb_bram1_v1c = '0;
            addrb_bram1_v2c = '0;
            addrb_bram1_v3c = '0;
        end
        if (enb_bram2) begin // reading from bram2 for addition
            addrb_bram2_v1a = s5_max_v_index_1;
            addrb_bram2_v2a = s5_max_v_index_1;
            addrb_bram2_v3a = s5_max_v_index_1;
            addrb_bram2_v1b = s5_max_v_index_2;
            addrb_bram2_v2b = s5_max_v_index_2;
            addrb_bram2_v3b = s5_max_v_index_2;
            addrb_bram2_v1c = s5_max_v_index_3;
            addrb_bram2_v2c = s5_max_v_index_3;
            addrb_bram2_v3c = s5_max_v_index_3;
        end else begin
            addrb_bram2_v1a = '0;
            addrb_bram2_v2a = '0;
            addrb_bram2_v3a = '0;
            addrb_bram2_v1b = '0;
            addrb_bram2_v2b = '0;
            addrb_bram2_v3b = '0;
            addrb_bram2_v1c = '0;
            addrb_bram2_v2c = '0;
            addrb_bram2_v3c = '0;
        end
        if (!choose_bram) begin // even steps: read from 1 write into 2
            va_add = tag_a_match ? doutb_bram1_v1a : doutb_bram2_v1a;
            vb_add = tag_b_match ? doutb_bram1_v1b : doutb_bram2_v1b;
            vc_add = tag_c_match ? doutb_bram1_v1c : doutb_bram2_v1c;
        end else if (choose_bram) begin // odd steps: read from 2, write into 1
            va_add = tag_a_match ? doutb_bram2_v1a : doutb_bram1_v1a;
            vb_add = tag_b_match ? doutb_bram2_v1b : doutb_bram1_v1b;
            vc_add = tag_c_match ? doutb_bram2_v1c : doutb_bram1_v1c;
        end else begin
            va_add = '0;
            vb_add = '0;
            vc_add = '0;
        end
        if (collision2_a) begin
            va_add = delayed_va1;
        end
        if (collision2_b) begin
            vb_add = delayed_vb1;
        end
        if (collision2_c) begin
            vc_add = delayed_vc1;
        end
        
    end
    
    logic signed [width-1:0] va_add_new, vb_add_new, vc_add_new;
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            va_add_new <= '0;
            vb_add_new <= '0;
            vc_add_new <= '0;
        end else begin
            va_add_new <= va_add + G_R_full + tmp_add_a;
            vb_add_new <= vb_add + G_n_2_full + tmp_add_b;
            vc_add_new <= vc_add + G_n_3_full + tmp_add_c;
        end
    end
    
    
    assign dina_bram1_v1a = va_add_new;
    assign dina_bram1_v2a = va_add_new;
    assign dina_bram1_v3a = va_add_new;
    assign dina_bram1_v1b = vb_add_new;
    assign dina_bram1_v2b = vb_add_new;
    assign dina_bram1_v3b = vb_add_new;
    assign dina_bram1_v1c = vc_add_new;
    assign dina_bram1_v2c = vc_add_new;
    assign dina_bram1_v3c = vc_add_new;
    assign dina_bram2_v1a = va_add_new;
    assign dina_bram2_v2a = va_add_new;
    assign dina_bram2_v3a = va_add_new;
    assign dina_bram2_v1b = vb_add_new;
    assign dina_bram2_v2b = vb_add_new;
    assign dina_bram2_v3b = vb_add_new;
    assign dina_bram2_v1c = vc_add_new;
    assign dina_bram2_v2c = vc_add_new;
    assign dina_bram2_v3c = vc_add_new;
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            next_tag_a <= '0;
            next_tag_b <= '0;
            next_tag_c <= '0;
        end else begin
            next_tag_a <= steps;
            next_tag_b <= steps;
            next_tag_c <= steps;
        end
    end
    
    // each bram has 3 copies to read v_i, v_j, v_k from them in same cycle
    // even cycles
    // v1: 
    blk_mem_gen_2 bram1_v1a (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v1a), // v_index_early for max_v_index. 
      .dina(dina_bram1_v1a),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v1a),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v1a), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v1a) 
    );
    blk_mem_gen_2 bram1_v1b (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v1b), // v_index_early for max_v_index. 
      .dina(dina_bram1_v1b),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v1b),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v1b), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v1b) 
    );
    blk_mem_gen_2 bram1_v1c (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v1c), // v_index_early for max_v_index. 
      .dina(dina_bram1_v1c),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v1c),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v1c), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v1c) 
    );
    // v2:
    blk_mem_gen_2 bram1_v2a (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v2a), // v_index_early for max_v_index. 
      .dina(dina_bram1_v2a),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v2a),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v2a), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v2a) 
    );
    blk_mem_gen_2 bram1_v2b (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v2b), // v_index_early for max_v_index. 
      .dina(dina_bram1_v2b),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v2b),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v2b), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v2b) 
    );
    blk_mem_gen_2 bram1_v2c (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v2c), // v_index_early for max_v_index. 
      .dina(dina_bram1_v2c),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v2c),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v2c), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v2c) 
    );
    // v3:
    blk_mem_gen_2 bram1_v3a (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v3a), // v_index_early for max_v_index. 
      .dina(dina_bram1_v3a),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v3a),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v3a), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v3a) 
    );
    blk_mem_gen_2 bram1_v3b (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v3b), // v_index_early for max_v_index. 
      .dina(dina_bram1_v3b),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v3b),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v3b), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v3b) 
    );
    blk_mem_gen_2 bram1_v3c (
      .clka(clk),    
      .ena(ena_bram1),    
      .wea(wea_bram1),     
      .addra(addra_bram1_v3c), // v_index_early for max_v_index. 
      .dina(dina_bram1_v3c),    // late write all_full_Gs at max_v_index
      .douta(douta_bram1_v3c),  
      .clkb(clk),  
      .enb(enb_bram1),    
      .web(0),     
      .addrb(addrb_bram1_v3c), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram1_v3c) 
    );

    // odd cycles
    // v1: 
    blk_mem_gen_3 bram2_v1a (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v1a), // v_index_early for max_v_index. 
      .dina(dina_bram2_v1a),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v1a),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v1a), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v1a) 
    );
    blk_mem_gen_3 bram2_v1b (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v1b), // v_index_early for max_v_index. 
      .dina(dina_bram2_v1b),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v1b),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v1b), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v1b) 
    );
    blk_mem_gen_3 bram2_v1c (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v1c), // v_index_early for max_v_index. 
      .dina(dina_bram2_v1c),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v1c),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v1c), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v1c) 
    );
    // v2:
    blk_mem_gen_3 bram2_v2a (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v2a), // v_index_early for max_v_index. 
      .dina(dina_bram2_v2a),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v2a),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v2a), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v2a) 
    );
    blk_mem_gen_3 bram2_v2b (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v2b), // v_index_early for max_v_index. 
      .dina(dina_bram2_v2b),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v2b),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v2b), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v2b) 
    );
    blk_mem_gen_3 bram2_v2c (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v2c), // v_index_early for max_v_index. 
      .dina(dina_bram2_v2c),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v2c),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v2c), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v2c) 
    );
    // v3:
    blk_mem_gen_3 bram2_v3a (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v3a), // v_index_early for max_v_index. 
      .dina(dina_bram2_v3a),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v3a),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v3a), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v3a) 
    );
    blk_mem_gen_3 bram2_v3b (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v3b), // v_index_early for max_v_index. 
      .dina(dina_bram2_v3b),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v3b),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v3b), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v3b) 
    );
    blk_mem_gen_3 bram2_v3c (
      .clka(clk),    
      .ena(ena_bram2),    
      .wea(wea_bram2),     
      .addra(addra_bram2_v3c), // v_index_early for max_v_index. 
      .dina(dina_bram2_v3c),    // late write all_full_Gs at max_v_index
      .douta(douta_bram2_v3c),  
      .clkb(clk),  
      .enb(enb_bram2),    
      .web(0),     
      .addrb(addrb_bram2_v3c), // late max_v_index for all_full_Gs. both cases
      .dinb('0),   
      .doutb(doutb_bram2_v3c) 
    );


//     tag
    logic [15:0] tag_a, tag_b, tag_c;
    logic [15:0] next_tag_a, next_tag_b, next_tag_c;
    logic tag_a_match, tag_b_match, tag_c_match; 
    logic wea_tag_a, wea_tag_b, wea_tag_c;
    assign wea_tag_a = wea_tag && !collision_a;
    assign wea_tag_b = wea_tag && !collision_b;
    assign wea_tag_c = wea_tag && !collision_c;
    blk_mem_gen_4 bram_tag_a (
      .clka(clk),   
      .ena(1),     
      .wea(wea_tag_a),  
      .addra(s6_max_v_index_1),  
      .dina(next_tag_a), 
      .clkb(clk),   
      .enb(enb_tag),   
      .addrb(s5_max_v_index_1),
      .doutb(tag_a)  
    );
    blk_mem_gen_4 bram_tag_b (
      .clka(clk),    
      .ena(1),     
      .wea(wea_tag_b),    
      .addra(s6_max_v_index_2),
      .dina(next_tag_b),  
      .clkb(clk),  
      .enb(enb_tag),     
      .addrb(s5_max_v_index_2), 
      .doutb(tag_b) 
    );
    blk_mem_gen_4 bram_tag_c (
      .clka(clk),  
      .ena(1),   
      .wea(wea_tag_c),      
      .addra(s6_max_v_index_3), 
      .dina(next_tag_c),   
      .clkb(clk),   
      .enb(enb_tag),    
      .addrb(s5_max_v_index_3),  
      .doutb(tag_c)  
    );
    assign tag_a_match = (tag_a != steps);
    assign tag_b_match = (tag_b != steps);
    assign tag_c_match = (tag_c != steps);
    
    logic collision_a, collision_b, collision_c;
    assign collision_a = (s5_max_v_index_1 == s6_max_v_index_1) && wea;
    assign collision_b = (s5_max_v_index_2 == s6_max_v_index_2) && wea;
    assign collision_c = (s5_max_v_index_3 == s6_max_v_index_3) && wea;
    logic signed [width-1:0] tmp_add_a, tmp_add_b, tmp_add_c;
    
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            tmp_add_a <= '0;
            tmp_add_b <= '0;
            tmp_add_c <= '0;
        end else begin    
            if (collision_a) begin
                tmp_add_a <= G_R_full;
            end else begin
                tmp_add_a <= '0;
            end
            if (collision_b) begin
                tmp_add_b <= G_n_2_full;
            end else begin
                tmp_add_b <= '0;
            end
            if (collision_c) begin
                tmp_add_c <= G_n_3_full;
            end else begin
                tmp_add_c <= '0;
            end
        end
    end
    
    logic collision2_a, collision2_b, collision2_c;
    logic signed [width-1:0] delayed_va1, delayed_vb1, delayed_vc1;  
    always_ff @(posedge clk) begin // keeping delayed values for collision2
        if (!reset_n) begin
            delayed_va1 <= '0;
            delayed_vb1 <= '0;
            delayed_vc1 <= '0;
            collision2_a <= 0;
            collision2_b <= 0;
            collision2_c <= 0;
        end else begin
            delayed_va1 <= va_add_new;
            delayed_vb1 <= vb_add_new;
            delayed_vc1 <= vc_add_new;
            collision2_a <= (s5_max_v_index_1 == s7_max_v_index_1) && wea;
            collision2_b <= (s5_max_v_index_2 == s7_max_v_index_2) && wea;
            collision2_c <= (s5_max_v_index_3 == s7_max_v_index_3) && wea;
        end
    end
    
endmodule

