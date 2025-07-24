module RACE_top #(
  parameter L = 7,
  parameter ALPHA_SHIFT = 4,
  parameter BETA_SHIFT = 4,
  parameter D = 16,
  parameter SAMPLE_SIZE = 16,
  parameter COEFF_SIZE = 16
)(
  input  wire clk,
  input  wire nrst,
  input  wire strobe,
  input  wire [SAMPLE_SIZE-1:0] in_real,
  input  wire [SAMPLE_SIZE-1:0] in_imag,
  output wire [SAMPLE_SIZE-1:0] out_real,
  output wire [SAMPLE_SIZE-1:0] out_imag
);

  wire strobe_resync;
  reg  q0, q1, q2;

  wire [SAMPLE_SIZE:0] mac_out_real;
  wire [SAMPLE_SIZE:0] mac_out_imag;

  wire [SAMPLE_SIZE:0] agc_out_real;
  wire [SAMPLE_SIZE:0] agc_out_imag;
  
  wire [COEFF_SIZE-1:0] rxx_real;
  wire [COEFF_SIZE-1:0] rxx_imag;
  wire [COEFF_SIZE-1:0] rxx;

  reg en;
  reg en_del;
  reg agc_en;
  reg [$clog2(2*L+1)-1:0] sel_cnt;
  
  //obviously enable blocks
  //en is active while sel_cnt counts to the 2*L+1
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      en <= 0;
    end else begin
      en <= (sel_cnt == 2*L+1) ? 1'b0 : 1'b1;
    end
  end
  
  //agc_en activates on negedge of en (same time mac data is ready)
  always @(posedge clk) begin
    en_del <= en;
    agc_en <= !en & en_del;
  end

 //just for selection of input taps, counts from 0 to 2*L+1
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sel_cnt <= 0;
    end else begin
      if (strobe_resync) begin 
        sel_cnt <= 0;
      end else if (sel_cnt == 2*L+1) begin
        sel_cnt <= 2*L+1;
      end else sel_cnt <= sel_cnt + 1;
    end
  end
  
  // synchronizator
  // catches negedge activating strobe_resync;
  always @(posedge clk) begin
    q0 <= strobe;
    q1 <= q0;
    q2 <= q1;
  end
  
  assign strobe_resync = q1 & !q2;

  //count average from imaginary and real rxx to use as coeffitients)))
  assign rxx = $signed($signed(rxx_real) + $signed(rxx_imag) + 16'd1) >>> 1;
  
  RACE_part #(L, ALPHA_SHIFT, BETA_SHIFT, SAMPLE_SIZE, COEFF_SIZE) i_RACE_real(
    .clk(clk),
    .clk_div(strobe_resync),
    .nrst(nrst),
    .en(en),
    .sel(sel_cnt),
    .in(in_real),
    .in_rxx(rxx),
    .out(mac_out_real),
    .out_rxx(rxx_real)
  );

  RACE_part #(L, ALPHA_SHIFT, BETA_SHIFT, SAMPLE_SIZE, COEFF_SIZE) i_RACE_imag(
    .clk(clk),
    .clk_div(strobe_resync),
    .nrst(nrst),
    .en(en),
    .sel(sel_cnt),
    .in(in_imag),
    .in_rxx(rxx),
    .out(mac_out_imag),
    .out_rxx(rxx_imag)
  );
  
  AGC i_agc(
    .clk(clk),
    .nrst(nrst),
    .en(agc_en),
    .in_real(mac_out_real),
    .in_imag(mac_out_imag),
    .out_real(agc_out_real),
    .out_imag(agc_out_imag)
  );

  localparam OVF = 2**(15);
  
  // 17.15 -> 16.15
  assign out_real = (agc_out_real[16 -: 2] == 2'b10) ? OVF   :
                    (agc_out_real[16 -: 2] == 2'b01) ? OVF-1 :
                     agc_out_real[15:0]; 

  assign out_imag = (agc_out_imag[16 -: 2] == 2'b10) ? OVF   :
                    (agc_out_imag[16 -: 2] == 2'b01) ? OVF-1 :
                     agc_out_imag[15:0];
  
endmodule