module top(input clk, rst); 
	
		wire [31:0] PC, if_id_NPC; 
		wire [31:0] instruction, if_id_IR ,sign_extended; //instruction
		
		wire [31:0] id_ex_A, id_ex_B, ex_mem_ALUOUT, mem_wb_ALUOUT; //data
		wire [31:0] A, B, branch_target, ALUOUT;
		
		wire PCsrc, RegWrite, ex_mem_RegWrite, mem_wb_RegWrite, ZERO;
		wire [4:0] rs, rt, rd, id_ex_RS, id_ex_RT, id_ex_RD, ex_mem_RD, mem_wb_RD;
		
		wire [1:0] selA, selB;
		wire [31:0] in1, in2, in3, in4;
		
		wire [1:0] ALUop, id_ex_ALUop;
		
		

		controlUnit c1 (/*output*/ RegWrite, eop, rs, rt, rd, ALUop, PC, /*input*/ instruction, sign_extended, clk, rst, ZERO);
		
		
		/*------------------ slot 1 -------------------------*/
		
		
		inst_mem m1 (instruction, clk, 1'b0, PC);
		
		IF_ID p1 (clk, rst, {instruction}, {if_id_IR}); //32 bits
		
		/*------------------ slot 2 ---------------- not considering load/store ----*/
		
		regfile32 r1 (clk, 1'b0,eop, mem_wb_RegWrite, rs, rt, mem_wb_RD, mem_wb_ALUOUT, A, B);
		
		Sign_extend_shift s1 (sign_extended, if_id_IR[15:0]);
		
		//generate ZERO
		Equal z1 (ZERO, in3, in4);
		
		ID_EX p2 (clk, rst, {rs, rt, ALUop, RegWrite, B, A, rd}, {id_ex_RS, id_ex_RT, id_ex_ALUop, id_ex_RegWrite, id_ex_B, id_ex_A, id_ex_RD}); //80 bits
		
		forwarding_unit_B f2 (in3, in4, rs, rt, ex_mem_RD, mem_wb_RD, ex_mem_RegWrite, mem_wb_RegWrite, ex_mem_ALUOUT, mem_wb_ALUOUT, A, B);
		
		
		/*------------------ slot 3 -------------------------*/
		mux32 mx2 (in1, id_ex_A, ex_mem_ALUOUT, mem_wb_ALUOUT, selA);
		mux32 mx3 (in2, id_ex_B, ex_mem_ALUOUT, mem_wb_ALUOUT, selB);
		
		forwarding_unit f1 (selA, selB, id_ex_RS, id_ex_RT, ex_mem_RD, mem_wb_RD, ex_mem_RegWrite, mem_wb_RegWrite);
		
		ALU a1 (ALUOUT, in1, in2, id_ex_ALUop); 
		
		EX_MEM p3 (clk, rst, {id_ex_RegWrite, id_ex_RD, ALUOUT}, {ex_mem_RegWrite, ex_mem_RD, ex_mem_ALUOUT}); //38 bits 
		
		
		
		/*------------------ slot 4 -------------------------*/
		MEM_WB p4 (clk, rst, {ex_mem_RegWrite, ex_mem_RD, ex_mem_ALUOUT}, {mem_wb_RegWrite, mem_wb_RD, mem_wb_ALUOUT}); //38 bits
		
		
		
		/*------------------ slot 5 -------------------------*/
		

endmodule
		
module ALU(output reg [31:0] out, input [31:0] A, input [31:0] B, input [1:0] OP);
//OP 00 add, 01 and, 10 or, 11 sub //
	always @ (*)
	begin
		case(OP)
		2'd0: out <= A+B;
		2'd1: out = A&B;
		2'd2: out = A|B;
		2'd3: out <= A-B;
		endcase
		
	end
	
endmodule

module controlUnit(output reg RegWrite,output reg eop2, output reg [4:0] rs, rt, rd, 
output reg [1:0] op, output [31:0] PC_out, input [31:0] instr_in, sign_extend, input clk, rst ,zero); 
	reg PCsrc; 
	reg [31:0] PC;
	reg eop;
	assign PC_out = PC;
	
	
	reg [31:0] instr;
	reg  cur, nxt;
	//reg [2:0] count;
	integer count=0;
	localparam idle = 1'b0, working = 1'd1;
	
//************************************* state calculation and output calculation ***************************//	
	//always @ (*)
	always@(negedge clk, posedge rst)
	begin
		case(cur)
		idle: 
			begin
				if(eop) 			// to keep it in idle state only
					begin
					eop = 1'b1;
					count = count +1'b1;
					eop2 = (count==4);
					end
				else 	
					eop = 1'b0;
					
				PC = 32'd0;	
				PCsrc = 1'b0;
				RegWrite = 1'bX;
				rs = 5'bXXXX;
				rt = 5'bXXXX;
				rd = 5'bXXXX;
				op = 2'bXX;
				
				if(eop) //stay in idle if eop reached
					nxt = idle;
				else
					nxt = working;
			end


		working: 
			begin
			
				/* --------- fetch ---------*/
				instr = instr_in;
				PCsrc = ((instr[28]) && (zero)); //when a particular instruction is branch
				
				if(PCsrc)
					PC = (PC) + sign_extend;
				else
					PC = PC +4;
				
				
				/* -------- decode --------*/
				rs = instr[25:21];
				rt = instr[20:16];
				rd = instr[15:11];
				RegWrite = (~(instr[28])); 
				
				
				/*---------- ex ----------*/
				case(instr[3:0]) 
					4'd0: op = 2'b00; //add
					4'd2: op = 2'b11; //sub
					4'd4: op = 2'b01; //and
					4'd5: op = 2'b10; //or
					default: op = 2'b00;
				endcase
				
			
				/*--------- mem ---------*/
				// no mem access, only R type
				
				
				/*--------- wb -----------*/
				//always write, only R type
				
		
				/*---------next state-----*/
				if(PC > 32'd24) 
					eop = 1'b1;
				else 
					eop = 1'b0;
					
					
				if(eop)
					nxt = idle;
				else
					nxt = working;
			end
		
		
			
		default: 
			begin
				eop = 0;
				PC = 32'dX;	
				PCsrc = 1'b0;
				RegWrite = 1'bX;
				rs = 5'bXXXX;
				rt = 5'bXXXX;
				rd = 5'bXXXX;
				op = 2'bXX;
				nxt = idle;
			end
			
		endcase
	end

//************************** state assignment ***************************************************//
	always @ (posedge clk, posedge rst)
		begin
			if(rst)
				cur <= idle;
			else
				cur <= nxt;
		end
			
endmodule

/* check equality*/
module Equal (output reg zero, input [31:0] A, B);
	
	always@(*)
	if(A == B)
		zero = 1'b1;
	else
		zero = 1'b0;

endmodule

/* forwarding unit to handle data hazards*/
module forwarding_unit (output reg [1:0] select_rs, select_rt, input [4:0] rs, rt, rd1, rd2, input RegWrite1, RegWrite2); //rd1 ex_mem.rd// rd2 mem_wb.rd// rs id_ex.rs// rt id_ex.rt
	
		always@(*)
		begin	
			begin
				if((rs != rd1) && (rs != rd2))
					select_rs = 2'b00;
				else if(RegWrite1 && (rs != 0) && (rs == rd1))
					select_rs = 2'b01;
				else if(RegWrite2 && (rs != 0) && (rs != rd1) && (rs == rd2))
					select_rs = 2'b10;
				else
					select_rs = 2'b00;
			end
			
			begin
				if((rt != rd1) && (rt != rd2))
					select_rt = 2'b00;
				else if(RegWrite1 && (rt != 0) && (rt == rd1))
					select_rt = 2'b01;
				else if(RegWrite2 && (rt != 0) && (rt != rd1) && (rt == rd2))
					select_rt = 2'b10;
				else
					select_rt = 2'b00;
			end
		end

endmodule

/* forwardig unit for control hazards_to make data available in deocode stage*/
module forwarding_unit_B (output reg [31:0] current_rs, current_rt, input [4:0] rs, rt, rd1, rd2, input RegWrite1, RegWrite2, input [31:0] ex_out, mem_out, A, B); //rd1 ex_mem.rd// rd2 mem_wb.rd// rs id_ex.rs// rt id_ex.rt
	
		always@(*)
		begin	
			begin
				if((rs != rd1) && (rs != rd2))
					current_rs = A;
				else if(RegWrite1 && (rs != 0) && (rs == rd1))
					current_rs = ex_out;
				else if(RegWrite2 && (rs != 0) && (rs != rd1) && (rs == rd2))
					current_rs = mem_out;
				else 
					current_rs =  A;
			end
			
			begin
				if((rt != rd1) && (rt != rd2))
					current_rt = B;
				else if(RegWrite1 && (rt != 0) && (rt == rd1))
					current_rt = ex_out;
				else if(RegWrite2 && (rt != 0) && (rt != rd1) && (rt == rd2))
					current_rt = mem_out;
				else 
					current_rt = B;
			end
		end

endmodule

/* 	pipeline registers
	size of each register calculated and kept minimum*/
module IF_ID (input clk, rst, input [31:0] d, output [31:0] q);

		genvar p;
		generate
		for (p = 0; p<32; p=p+1)
			begin: ff
			d_ff FLIP (d[p], clk, reset, q[p]);
			end
		endgenerate
		
endmodule

module ID_EX (input clk, rst, input [81:0] d, output [81:0] q);

		genvar p;
		generate
		for (p = 0; p<82; p=p+1)
			begin: ff
			d_ff FLIP (d[p], clk, reset, q[p]);
			end
		endgenerate
		
endmodule

module EX_MEM (input clk, rst, input [37:0] d, output [37:0] q);

		genvar p;
		generate
		for (p = 0; p<38; p=p+1)
			begin: ff
			d_ff FLIP (d[p], clk, reset, q[p]);
			end
		endgenerate
		
endmodule

module MEM_WB (input clk, rst, input [37:0] d, output [37:0] q);

		genvar p;
		generate
		for (p = 0; p<38; p=p+1)
			begin: ff
			d_ff FLIP (d[p], clk, reset, q[p]);
			end
		endgenerate
		
endmodule

/* ------------------------------------- d flipflop -------------------------------------------*/
module d_ff(input d,clk,reset, output reg q);

	always@(negedge clk)
		begin
			if(reset == 1'b0)
				q <= 1'b0;
			else
				q <= d;
		end
		
endmodule

/*instruction memory defination and initialisation from text file*/
module inst_mem(output reg [31:0] instruction, input clk, input rst, input [31:0] PC); 

	reg [7:0] instMem [0:35];
	integer i;

	initial
	$readmemh("instructions_final.txt", instMem);

	always@(negedge clk)
		begin
			if(rst) 
				begin
					instruction <= 32'dZ;		
					for(i = 0; i < 36; i = i+1)
					instMem[i] <= 32'd0;		//initialise memory to zero
				end
			else
			instruction <= {instMem[PC+3],instMem[PC+2],instMem[PC+1],instMem[PC]};

		end

endmodule


/*2:1 mux of size 4 bits*/
module mux3 (output reg [4:0] ALUin, input [4:0] a0, a1, input ALUsrc);

	always@(*)
		begin
			if(ALUsrc)
				ALUin = a1;
			else
				ALUin = a0;
		end
		
endmodule

/*4:1 mux of size 32 bits*/
module mux32 (output reg [31:0] ALUin, input [31:0] a0, a1, a2, input [1:0] ALUsrc);

	always@(*)
		begin
			case(ALUsrc)
			2'b00: ALUin = a0;
			2'b01: ALUin = a1;
			2'b10: ALUin = a2;
			default: ALUin = a0;
			endcase
		end
		
endmodule

/* register file of 32 registers each of 32 bits*/ 
module regfile32 (input clk, rst,eop, writeEnable, input [4:0] rs, rt, rd, input [31:0] write_data, output reg [31:0] read1, read2);
	
	reg [31:0] regfile [0:31];
	initial 
	$readmemh("register.txt", regfile);
	integer f,i;
	
	
 	always@(posedge clk, posedge rst)
		begin
			if(rst)
				for (i=0; i <32; i=i+1)
					regfile[i] = 32'd0;
			else
				begin
					if(writeEnable)
						regfile[rd] = write_data;
					
					read1 = regfile[rs];
					read2 = regfile[rt];
				end
		end
			
	always @ (posedge eop)
		begin
		f = $fopen("output_reg.txt", "w");
			if (f) $display("File was opened successfully : %0d", f);
				else $display("File was NOT opened successfully : %0d", f);
				for(i = 0; i < 32; i = i+1)
					
					$fwrite(f, "%h\n", regfile[i]);
					$fclose(f);
		end

endmodule

/*sign extend and shift module*/
module Sign_extend_shift (output reg [31:0] sign_extended, input [15:0] in);

	always@(*)
		sign_extended = ({{16{in[15]}}, {in[15:0]}} << 2);
		
endmodule
	