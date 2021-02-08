`timescale 1ns/1ps
module loctag (
  // 50MHz clock input
  input  clk,
  input  reset,
  output lt5534_en,
  output adc_cs,
  output dc_clk,
  input  adc_so,
  input  trig,

  output ctrl_1,

  input  force_fs,
  input  [1:0] mode,
  output led,
  );

  // 常量输出
  assign t5534_en = 1'b0;
  
  // MAC协议参数
  localparam Q = 2;

  ///////////////// 定时参数 /////////////
  localparam TRIG_RISE_TIME = 0;  // uint: 20ns
  // 探测包

  // 11b
  localparam T_B_INFO_GOT = 2;
  localparam T_B_MOD_START = 144;
  localparam T_B_CRC_START = 320;
  localparam T_B_CRC_END = 32;
  // 11n
  localparam T_N_INFO_GOT = 2;
  localparam T_N_MOD_START = 64;
  localparam T_N_MOD_END = 128;

  ///////////////// 状态定义 ///////////////
  localparam IDLE = 0;
  localparam FORCE_FS = 1;  
  // 请求包，2~9

  // 11b, 10~17
  localparam B_START = 10;
  localparam B_INFO_GOT = 11;  // 已获得RSS和MAC协议运行结果
  localparam B_MOD_START = 12;
  localparam B_CRC_START = 13;
  // 11n, 18~25
  localparam N_START = 18;
  localparam N_INFO_GOT = 19;
  localparam N_MOD_START = 20;

  ///////////////// 变量与信号定义 ///////////////
  // 状态变量
  reg [4:0] state = IDLE;
  reg [4:0] next_state = IDLE;
  // 由trig和定时驱动状态的转移 
  reg [5:0] divide_counter = 0;
  reg [26:0] us_counter = 0;
  
  reg counter_rst = 0;

  always @(posedge clk) begin
    if (reset) begin
      divide_counter <= 0;
      us_counter <= 0;
    end else if (counter_rst) begin
      divide_counter <= 0;
      us_counter <= 0;
    end else if (divide_counter == 49) begin
      divide_counter <= 0;
      us_counter <= us_counter + 1;
    end else begin
      divide_counter <= divide_counter + 1;
      us_counter <= us_counter;
    end 
  end
  
  always @(posedge clk) begin
    if (force_fs) begin
      state <= FORCE_FS;
      counter_rst <= 1;
    end else if (~trig) begin
      state <= IDLE;
      counter_rst <= 1;
    end else begin
      case (state)

        IDLE : begin
          case (mode)
            2'b10: begin
              state <= B_START;
            end
            2'b01: begin
              state <= N_START;
            end
            // 2'b11: begin
            //   state <= P_START;
            // end
            default: begin
              state <= IDLE;
            end
          endcase
          counter_rst <= 1;
        end

        B_START : begin
          if (us_counter == T_B_INFO_GOT) begin
            state <= B_INFO_GOT;
            counter_rst <= 1;
          end else begin
            state <= B_START;
            counter_rst <= 0;
          end
        end

        B_INFO_GOT : begin
          if (us_counter == T_B_MOD_START) begin
            state <= B_MOD_START;
            counter_rst <= 1;
          end else begin
            state <= B_INFO_GOT;
            counter_rst <= 0;
          end
        end
        
        B_MOD_START : begin
          if (us_counter == T_B_CRC_START) begin
            state <= B_CRC_START;
            counter_rst <= 1;
          end else begin
            state <= B_MOD_START;
            counter_rst <= 0;
          end
        end
        
        B_CRC_START : begin
          if (us_counter == T_B_CRC_END) begin
            state <= IDLE;
            counter_rst <= 1;
          end else begin
            state <= B_CRC_START;
            counter_rst <= 0;
          end
        end

        N_START : begin
          if (us_counter == T_N_INFO_GOT) begin
            state <= N_INFO_GOT;
            counter_rst <= 1;
          end else begin
            state <= N_START;
            counter_rst <= 0;
          end
        end

        N_INFO_GOT : begin
          if (us_counter == T_N_MOD_START) begin
            state <= N_MOD_START;
            counter_rst <= 1;
          end else begin
            state <= N_INFO_GOT;
            counter_rst <= 0;
          end
        end
        
        N_MOD_START : begin
          if (us_counter == T_N_MOD_END) begin
            state <= IDLE;
            counter_rst <= 1;
          end else begin
            state <= N_MOD_START;
            counter_rst <= 0;
          end
        end
        
        default: begin
          state <= IDLE;
          counter_rst <= 1;
        end 


        default: begin
          state <= IDLE;
          counter_rst <= 1;
        end

      endcase
    end // if-else-end  
  end 

endmodule
