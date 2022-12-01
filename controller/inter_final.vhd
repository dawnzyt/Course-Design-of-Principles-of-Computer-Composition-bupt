-- --------------------------------------------------------------------
-- 文件名 inter_final.vhd                              中断硬连线控制器
-- --------------------------------------------------------------------

-- 描述
-- 题目三：基于TEC-8系统完成中断功能硬连线控制器设计。

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
	SWC:in std_logic;--模式控制
	SWB:in std_logic;
	SWA:in std_logic;
	W3:in std_logic;--三拍
	W2:in std_logic;
	W1:in std_logic;
	CLR:in std_logic;--重置信号
	T3:in std_logic;--第三个节拍脉冲，其余两个脉冲将再tec-8实验台上自动与各控制信号作用
	IRH:in std_logic_vector(3 downto 0);--操作码im7-im4
	C:in std_logic;--算术运算进位标志
	Z:in std_logic;--结果为0标志
	
	--中断相关
	MF:in std_logic;--主时钟脉冲
	PULSE:in std_logic;--pulse信号
	
	--输出
	DRW:out std_logic;--将总线数据写入RD1、RD0选中的寄存器（LDd有效）
	PCINC:out std_logic;--PC自加
	LPC:out std_logic;--BUS->PC
	LAR:out std_logic;--BUS->AR
	PCADD:out std_logic;--PC+偏移量（IR3-IR0）
	ARINC:out std_logic;--AR自加
	SELCTL:out std_logic;--=1时二选一选择器，RD1、RD0、RS1、RS0由SEL3-0决定。=0则由IR3-0决定
	MEMW:out std_logic;--写存储器信号
	LIR:out std_logic;--ISN7-ISN0(双端口存储器右端)->IR
	LDZ:out std_logic;--结果为0标志
	LDC:out std_logic;--进位标志
	CIN:out std_logic;--ALU的低位进位信号
	S:out std_logic_vector(3 downto 0);--ALU的选择方式
	M:out std_logic;--=1 ALU逻辑运算
	ABUS:out std_logic;--ALU->DBUS
	SBUS:out std_logic;--输入->DBUS
	MBUS:out std_logic;--存储器->DBUS
	SHORT:out std_logic;--只有W1
	LONG:out std_logic;--+W3
	SEL0:out std_logic;
	SEL1:out std_logic;
	SEL2:out std_logic;
	SEL3:out std_logic;
	STOP:out std_logic--停机


	
	);
END controller ;
ARCHITECTURE exm OF controller IS
	signal ST0:std_logic; --一个FLAG，=1表示第二阶段（见顺序硬布线控制器流程图）
	signal SST0:std_logic;--动态改变的信号，指示下一拍是第几个阶段，=1表示下一拍是第二个阶段。在每拍结束时通过检测SST0来改变ST0。
	
	--中断相关
	signal ST1:std_logic;--=1指示下一条指令进入中断前状态（前提：当前指令最后一拍执行完毕时INT有效），执行关中断+LD中断服务子程序首地址，准备进入中断服务子程序
	signal SST1:std_logic;--动态改变ST1，SST1=1指示下一条指令进入中断前状态（需执行完当前指令）。即INT=1且PULSE信号有效。
	signal INTDI:std_logic:='0';--禁止中断信号（仅在关中断节拍有效）：用来置EN_INT为0，即禁止中断持续到中断子程序结束即执行IRET命令（开中断）（CPU执行中断服务子程序时期）。
	signal INTEN:std_logic:='0';--允许中断信号（仅在开中断节拍有效）：用来置EN_INT为1，即允许中断持续到中断前状态（关中断前）（CPU正常运行时期）。
	signal EN_INT:std_logic;--=1目前CPU的状态是可以允许中断的，也就是正常运行期间。=0表示禁止中断，即中断服务子程序状态。
	signal INT:std_logic;--=1：实际上就是CPU正常执行指令期间PULSE脉冲的有效时期，在禁止中断时（EN_INT=0）无效（执行中断服务子程序时期）
	--PULSE脉冲宽度取决于按下按钮的时间，因此要使得CPU进入中断前状态（ST1=1），我们应当在每条指令的最后一拍长按pulse信号使得INT有效，使得在
	--该拍中SST1始终有效，使得ST1有效（一拍的下降沿赋值），从而下一步进入中断前状态。
	
	signal SWCBA:std_logic_vector(2 downto 0);
	BEGIN
		SWCBA<=SWC & SWB & SWA;--并置
	--处理ST0信号
	process(CLR,T3)
	begin
	if(T3'event and T3='0')THEN	--下降沿
		if(SST0='1')THEN--检测指示下一阶段的信号
			ST0<='1';
		end if;
		if(W2='1' and SWCBA="100" and ST0='1')then--写寄存器的特判：防止循环第二阶段，其他如写存、读存为了方便一直循环在ST1=1除非CLR=0。
			ST0<='0';
		end if;
	end if;
-- reset优先级更高
	if(CLR='0')then
		ST0<='0';
	end if;
end process;
	--------------------------------------------------------------------------------------
	
	--EN_INT允许中断标记,和INT中断中标记
	process(CLR,MF,EN_INT,PULSE)
	begin
		if(MF'event and MF='1')then--每个时钟检测是否发生中断
			EN_INT<=INTEN or((not INTDI) and EN_INT);--EN_INT=1后只有在INTDI信号有效后才会变为0。同理EN_INT=0后只有在INTEN信号有效后等于1。
		end if;
		if(CLR='0')then
			EN_INT<='1';--重置后是允许中断，即正常CPU状态
		end if;
		INT<=EN_INT and PULSE;--中断中
	end process;
	--------------------------------------------------------------------------------------
	
	--ST1中断前状态，执行关中断（DI）+LD中断服务子程序首地址（仅指进入中断服务子程序前的一小段时间）
	process(T3,CLR)
	begin
		if(T3'event and T3='0')then
			if(SST1='1')then--SST1=1当且仅当执行某条指令最后一个拍结束时INT=1（pulse有效且EN_INT有效）
				ST1<='1';
			end if;
			if(ST1='1'and EN_INT='0' and W2='1')then--结束中断前状态：关中断后将ST1置0
				ST1<='0';
			end if;
		end if;
		if(CLR='0')then
			ST1<='0';--重置后为非中断前状态
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
		
		--中断相关
		SST1<='0';
		INTDI<='0';
		INTEN<='0';
		case SWCBA is
			when "100"=>--写寄存器
				STOP<='1';
				SBUS<=W1 or W2;
				SELCTL<=W1 or W2;
				DRW<=W1 or W2;
				SST0<=(not ST0) and W2;
				SEL3<=ST0;
				SEL2<=W2;
				SEL1<=((not ST0)and W1)or(ST0 and W2);
				SEL0<=W1;
			when "011"=>--读寄存器
				STOP<='1';
				SELCTL<=W1 or W2;
				SEL3<=W2;
				SEL2<='0';
				SEL1<=W2;
				SEL0<=W1 or W2;
			when "010"=>--读存储器
				SBUS<=(not ST0) and W1;
				LAR<=(not ST0) and W1;
				STOP<='1';
				SHORT<='1';	
				SELCTL<=W1;
				SST0<=(not ST0)and W1;
				MBUS<=ST0 and W1;
				ARINC<=ST0 and W1;
			when "001"=>--写存储器
				SBUS<=W1;
				LAR<=(not ST0) and W1;
				STOP<='1';
				SHORT<='1';
				SELCTL<=W1;
				SST0<=(not ST0)and W1;
				MEMW<=ST0 and W1;
				ARINC<=ST0 and W1;
			when "000"=>--取指（中断发生处）
				if(ST1='1')then--中断前状态，执行指令：关中断+LD中断服务子程序首地址的状态
					INTDI<=W1;--EN_INT会随之变为0。
					SBUS<=W2;
					LPC<=W2;
					----调试信号
					SEL3<=EN_INT;
					SEL2<=INTDI;
					SEL1<=INTEN;
					SEL0<=INT;
					----
					STOP<='1';
				else--ST1=0非中断前状态
				
					--ST0=0：第一阶段是输入首地址；注-执行中断服务子程序没有ST0=0即第一阶段（ST0一定等于1，因为其在执行指令后进行中断）
					if(ST0='0')then
						--LPC
						SBUS<=W1;
						LPC<= W1;
						SST0<=W1;
						SHORT<=W1;
						STOP<='1';

						
						--同步R3寄存器LD R3
						SEL3<=W1;
						SEL2<=W1;

						SELCTL<=W1;
						DRW<=W1;
					else--ST0=1第二阶段
						--这里分为CPU正常运行状态和中断服务子程序状态-执行指令；状态区分取决于EN_INT：=1即正常状态；=0即中断服务状态。
						LIR<=W1;
						PCINC<=W1;
						
						--正常执行指令的第一拍需同步R3,即执行INC R3
						ABUS<=W1 and EN_INT;
						SEL3<=W1 and EN_INT;
						SEL2<=W1 and EN_INT;
						
						SELCTL<=W1 and EN_INT;
						DRW<=W1 and EN_INT;
						if(EN_INT='1'and W1='1')then
							S<="0000";--ALU模式F=A+1
						end if;
						--CPU正常状态：直到当前指令结束长按pulse使INT有效，从而使SST1在每条指令最后一拍为1。
						--CPU中断服务状态：无法中断，因为已经执行关中断指令。
						if(W1='0')then--注意，W1和W2、W3需分开判断，因为添加了中断功能可能会出现DRW<=W1且DRW<=W2产生信号覆盖的情况
							case IRH is
								when "0000"=>--nop信号跳过
									NULL;
								when "0001"=>--add
									S<="1001";
									CIN<=W2;
									ABUS<=W2;
									DRW<=W2;
									LDZ<=W2;
									LDC<=W2;
									
									SST1<=W2 and INT;
								when "0010"=>--sub
									S<="0110";
									ABUS<=W2;
									DRW<=W2;
									LDZ<=W2;
									LDC<=W2;
									
									SST1<=W2 and INT;
								when "0011"=>--and
									M<=W2;
									S<="1011";
									ABUS<=W2;
									DRW<=W2;
									LDZ<=W2;
									
									SST1<=W2 and INT;
								when "0100"=>--inc
									S<="0000";
									ABUS<=W2;
									DRW<=W2;
									LDZ<=W2;
									LDC<=W2;
									
									----调试信号
									SEL3<=INT;
									SEL2<=INTEN;
									SEL1<=INTDI;
									SEL0<=EN_INT;
									----
									SST1<=W2 and INT;
								when "0101"=>--LD
									M<=W2;
									S<="1010";
									ABUS<=W2;
									LAR<=W2;
									LONG<=W2;
									DRW<=W3;
									MBUS<=W3;

									SST1<=W3 and INT;
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
									
									SST1<=W3 and INT;
								when "0111"=>--JC
									STOP<=W2;--CPU正常执行指令情况下JC和JZ没有办法同步R3寄存器中的PC值，因此该两条指令只在中断程序中有效。
									PCADD<=C and W2 and not EN_INT;
									
									SST1<=W2 and INT;
								when "1000"=>--JZ
									STOP<=W2;
									PCADD<=Z and W2 and not EN_INT;
									
									SST1<=W2 and INT;
								when "1001"=>--JMP
									M<=W2;
									S<="1010"; --当CPU处于正常状态时，我们不仅要使得Rd->PC,还要同步更新R3即Rd->R3。但是我们没有办法记录Rd寄存器的地址（因为它是JMP指令中的IR3-IR0中的值），而IR3、IR2确定了RD1、RD0（SELCTL无效），从而确定了LRd（d=0,1,2,3），因此我们固定IR3、IR2等于11，将JMP的指令格式变为1001 11Rd，因此LPC的寄存器应该从B出，ABUS有效的同时使DRW有效就可以实现同步Rd->R3了，从而完成同步更新R3寄存器的值。
									ABUS<=W2;  --当CPU处于中断程序状态时，直接改变PC即可。为了方便统一，我们将中断硬布线所有的JMP指令格式都令为1001 11Rd。
									LPC<=W2;
									DRW<=W2 and EN_INT; --CPU正常状态同步LD R3。
									
									SST1<=W2 and INT;
									--正常执行R3同步JMP

								when "1010"=>--新增out-A
									M<=W2;
									S<="1111";
									ABUS<=W2;
									
									SST1<=W2 and INT;
									
								when "1011"=>--IRET：开中断；R3->PC。注意在IRET命令中不会相应SST1置其为1，防止多级中断（一个寄存器无法实现）
									INTEN<=W2;
									STOP<=W2 or W3;
									LONG<=W2;
									----调试用
									SEL3<=INT;
									SEL2<=INTEN;
									SEL1<=INTDI;
									SEL0<=EN_INT;
									----------
									--R3->PC
									LPC<=W3;
									ABUS<=W3;
									SELCTL<=W3;
									if(W3='1')then
										S<="1111";
									end if;
									M<=W3;
									SEL3<=W3;
									SEL2<=W3;

								when "1100"=>--新增MOV Rd Rs Rd<-Rs
									M<=W2;
									ABUS<=W2;
									S<="1010";
									DRW<=W2;
									
									SST1<=W2 and INT;
								when "1101"=>--新增or
									M<=W2;
									S<="1110";
									ABUS<=W2;
									DRW<=W2;
									LDZ<=W2;
									
									SST1<=W2 and INT;
								when "1110"=>--STP
									STOP<='1';
								when others=>NULL;
							end case;
						end if;
					end if;
					
				end if;
			when others =>NULL;
		end case;
	end process;
end exm;	