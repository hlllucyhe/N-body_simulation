module pe_core_tb;


  pe_core pe_inst (
  // Connect ports as needed for the testbench
  );
  lut lut_inst (
  // Connect ports as needed for the testbench
  );



  initial begin
    $dumpfile("./pe_core_tb.vcd");
    $dumpvars(0, pe_core_tb);


    $display("================================================================================");
    $display("PE Core Testbench - N-body Simulation Processing Element");
    $display("================================================================================");
    $display("Clock (clk1):  Hz");
    $display("================================================================================\n");
  end

endmodule
