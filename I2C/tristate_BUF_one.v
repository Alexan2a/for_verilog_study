module tristate_BUF_1 (
  output wire  I,
  input  wire  O,
  input  wire  T,
  inout  wire  IO
);

  assign I = IO;
  assign IO = T ? 1'b1 : O;

endmodule