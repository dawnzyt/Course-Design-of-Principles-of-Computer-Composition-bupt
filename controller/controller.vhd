-- --------------------------------------------------------------------
-- 文件名 order_final.vhd                              顺序硬连线控制器
-- --------------------------------------------------------------------

-- 描述
-- 题目一：基于Altera CPM7128的硬连线控制器设计按照给定数据格式、指令系统和数据通路，
--         根据所提供的器件要求，自行设计一个基于硬布线控制器的顺序模型处理机
-- 基本功能：根据设计方案，在TEC-8上进行组装、调试运行 
-- 附加功能：
-- a.在原指令基础上要求扩指至少三条
-- b.修改PC指针功能（任意指针）

-- --------------------------------------------------------------------
-- 版本日期	v1.0 	2022.8.31
-- --------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
ENTITY controller IS
	PORT(
	--输入
	SWC:in std_logic;--模型控制
	SWB:in std_logic;
	SWA:in std_logic;
	W3:in std_logic;--三拍
	W2:in std_logic;
	W1:in std_logic;
	CLR:in std_logic;--重置信号
	T3:in std_logic;--第三个节拍脉冲，其余两个脉冲将再tec-8实验台上自动与各控制信号作用
	IRH:in std_logic_vector(3 downto 0);--即操作码im7-im4
	C:in std_logic;--进位标志
	Z:in std_logic;--结果为0标志
	
	--输出
	DRW:out std_logic;--将总线数据写入RD1、RD0选中的寄存器
	PCINC:out std_logic;--PC自加,SWCBA="000"取指时有效
	LPC:out std_logic;--SBUS->PC
	LAR:out std_logic;--SBUS->AR
	PCADD:out std_logic;--PC加偏移量（IR3-IR0）
	ARINC:out std_logic;--AR自加
	SELCTL:out std_logic;--=1时，A、B端口寄存器分别为SEL3 SEL2和SEL1 SEL0选中的寄存器
	MEMW:out std_logic;--写存储器信号
	LIR:out std_logic;--ISN7-ISN0(双端口存储器右端)->IR
	LDZ:out std_logic;--结果为0标志
	LDC:out std_logic;--进位标志
	CIN:out std_logic;--ALU的低位进位信号
	S:out std_logic_vector(3 downto 0);--ALU的控制信号
	M:out std_logic;--=1表示逻辑运算
	ABUS:out std_logic;--ALU->DBUS
	SBUS:out std_logic;--输入->DBUS
	MBUS:out std_logic;--存储器->DBUS
	SHORT:out std_logic;--只有W1
	LONG:out std_logic;--W1、W2、W3
	SEL0:out std_logic;
	SEL1:out std_logic;
	SEL2:out std_logic;
	SEL3:out std_logic;
	STOP:out std_logic--停机
	);
END controller ;
ARCHITECTURE exm OF controller IS
	signal ST0:std_logic; --一个FLAG，=1表示第二阶段（如=1时W1、W2表示第二个的阶段的W1、W2也即W3、W4）
	signal SST0:std_logic;--动态改变的信号，指示下一拍是第几个阶段，=1表示下一拍是第二个阶段。在每拍结束时通过检测SST0来改变ST0。
	signal SWCBA:std_logic_vector(2 downto 0);
BEGIN
	SWCBA<=SWC & SWB & SWA;--并置
	--处理信号
	process(CLR,T3)
	begin
		if(T3'event and T3='0')THEN	--下降沿
			if(SST0='1')THEN--检测指示下一阶段的信号
				ST0<='1';
			end if;
			if(W2='1' and SWCBA="100" and ST0='1')then--写寄存器特判防止循环第二阶段	
				ST0<='0';
			end if;
		end if;
		-- reset
		if(CLR='0')then
			ST0<='0';
		end if;
	end process;
	
	process(SWCBA,IRH,C,Z,W1,W2,W3,ST0)
	begin
		--初始化各信号
		DRW<='0';
		PCINC<='0';
		LPC<='0';
		LAR<='0';
		PCADD<='0';
		ARINC<='0';
		SELCTL<='0';
		MEMW<='0';
		LIR<='0';
		LDZ<='0';
		LDC<='0';
		CIN<='0';
		S<="0000";
		M<='0';
		ABUS<='0';
		SBUS<='0';
		MBUS<='0';
		SHORT<='0';
		LONG<='0';
		SEL0<='0';
		SEL1<='0';
		SEL2<='0';
		SEL3<='0';
		STOP<='0';
		SST0<='0';
		case SWCBA is
			when "100"=>--写寄存器
				STOP<='1';
				SBUS<='1';
				SELCTL<='1';
				DRW<='1';
				SST0<=(not ST0) and W2;
				SEL3<=ST0;
				SEL2<=W2;
				SEL1<=((not ST0)and W1)or(ST0 and W2);
				SEL0<=W1;
			when "011"=>--读寄存器
				STOP<='1';
				SELCTL<='1';
				SEL3<=W2;
				SEL2<='0';
				SEL1<=W2;
				SEL0<='1';
			when "010"=>--读存储器
				SBUS<=(not ST0) and W1;
				LAR<=(not ST0) and W1;
				STOP<='1';
				SHORT<='1';
				SELCTL<='1';
				SST0<=(not ST0)and W1;
				MBUS<=ST0 and W1;
				ARINC<=ST0 and W1;
			when "001"=>--写存储器
				SBUS<=W1;
				LAR<=(not ST0) and W1;
				STOP<='1';
				SHORT<='1';
				SELCTL<='1';
				SST0<=(not ST0)and W1;
				MEMW<=ST0 and W1;
				ARINC<=ST0 and W1;
			when "000"=>--取指
				--第一阶段是输入首地址
				SBUS<=(not ST0) and W1;
				LPC<=(not ST0) and W1;
				SST0<=(not ST0) and W1;
				SHORT<=(not ST0) and W1;
				STOP<=(not ST0);--不能让STOP<=(not ST0) and W1：W1刚开始为0，不能使按了CLR后停机。
				--下面是第二阶段，第一阶段只有W1，第二阶段W1是load指令且PC自加。W2后则执行指令。
				LIR<=ST0 and W1;
				PCINC<=ST0 and W1;
				case IRH is
					when "0001"=>--add
						S<="1001";
						CIN<=W2;
						ABUS<=W2;
						DRW<=W2;
						LDZ<=W2;
						LDC<=W2;
					when "0010"=>--sub
						S<="0110";
						ABUS<=W2;
						DRW<=W2;
						LDZ<=W2;
						LDC<=W2;
					when "0011"=>--and
						M<=W2;
						S<="1011";
						ABUS<=W2;
						DRW<=W2;
						LDZ<=W2;
					when "0100"=>--inc
						S<="0000";
						ABUS<=W2;
						DRW<=W2;
						LDZ<=W2;
						LDC<=W2;
					when "0101"=>--LD
						M<=W2;
						S<="1010";
						ABUS<=W2;
						LAR<=W2;
						LONG<=W2;
						DRW<=W3;
						MBUS<=W3;
					when "0110"=>--ST
						M<=W2 or W3;
						if(W2='1')then
							S<="1111";
						else
							S<="1010";
						end if;
						ABUS<=W2 or W3;
						LAR<=W2;
						LONG<=W2;
						MEMW<=W3;
					when "0111"=>--JC
						PCADD<=C and W2;
					when "1000"=>--JZ
						PCADD<=Z and W2;
					when "1001"=>--JMP
						M<=W2;
						S<="1111";
						ABUS<=W2;
						LPC<=W2;
					when "1101"=>--新增or
						M<=W2;
						S<="1110";
						ABUS<=W2;
						DRW<=W2;
						LDZ<=W2;
					when "1010"=>--新增out-A
						M<=W2;
						S<="1111";
						ABUS<=W2;
					when "1100"=>--新增MOV Rd Rs Rd<-Rs
						M<=W2;
						ABUS<=W2;
						S<="1010";
						DRW<=W2;
					when "1110"=>--STP
						STOP<='1';
					when others=>NULL;
				end case;
				if(W1='1')then
					S<="0000";
				end if;
			when others =>NULL;
		end case;
	end process;
end exm;	