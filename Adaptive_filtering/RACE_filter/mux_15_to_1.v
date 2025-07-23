module mux_15_to_1 #(parameter SIZE = 16)(
  input  wire [3:0]      Sel,
  input  wire [SIZE-1:0] A0,
  input  wire [SIZE-1:0] A1,
  input  wire [SIZE-1:0] A2,
  input  wire [SIZE-1:0] A3,
  input  wire [SIZE-1:0] A4,
  input  wire [SIZE-1:0] A5,
  input  wire [SIZE-1:0] A6,
  input  wire [SIZE-1:0] A7,
  input  wire [SIZE-1:0] A8,
  input  wire [SIZE-1:0] A9,
  input  wire [SIZE-1:0] A10,
  input  wire [SIZE-1:0] A11,
  input  wire [SIZE-1:0] A12,
  input  wire [SIZE-1:0] A13,
  input  wire [SIZE-1:0] A14,
  output wire [SIZE-1:0] B
);

  assign B = (Sel == 4'b0000) ? A0  :
             (Sel == 4'b0001) ? A1  :
             (Sel == 4'b0010) ? A2  :
             (Sel == 4'b0011) ? A3  :
             (Sel == 4'b0100) ? A4  :
             (Sel == 4'b0101) ? A5  :
             (Sel == 4'b0110) ? A6  :
             (Sel == 4'b0111) ? A7  :
             (Sel == 4'b1000) ? A8  :
             (Sel == 4'b1001) ? A9  :
             (Sel == 4'b1010) ? A10 :
             (Sel == 4'b1011) ? A11 :
             (Sel == 4'b1100) ? A12 :
             (Sel == 4'b1101) ? A13 :
             (Sel == 4'b1110) ? A14 :
             {SIZE{1'b0}};

endmodule
