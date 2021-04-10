module TB();

	reg clk, rst;

	top DUT (clk, rst);
	
	initial	
		begin
			clk = 0;
			rst = 1;
			#3 rst = 0;
			#750 $finish;
		end
		
	always
		#05 clk = ~clk;
	
	initial
		begin
			$dumpfile("pipeline_VCD.vcd");
			$dumpvars;
		end
		

endmodule