module mux_7_to_1 #(parameter SIZE = 16)(
  input  wire [2:0]      Sel,
  input  wire [SIZE-1:0] A0,
  input  wire [SIZE-1:0] A1,
  input  wire [SIZE-1:0] A2,
  input  wire [SIZE-1:0] A3,
  input  wire [SIZE-1:0] A4,
  input  wire [SIZE-1:0] A5,
  input  wire [SIZE-1:0] A6,
  output wire [SIZE-1:0] B
);

  assign B = (Sel == 3'b000) ? A0 :
             (Sel == 3'b001) ? A1 :
             (Sel == 3'b010) ? A2 :
             (Sel == 3'b011) ? A3 :
             (Sel == 3'b100) ? A4 :
             (Sel == 3'b101) ? A5 :
             (Sel == 3'b110) ? A6 :
              0;

endmodule
