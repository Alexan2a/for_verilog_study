module tristate_BUF (
  output wire  I,
  input  wire  O,
  input  wire  T,
  inout  wire  IO
);

  assign I = IO;
  assign IO = T ? 1'bz : O;

endmodule