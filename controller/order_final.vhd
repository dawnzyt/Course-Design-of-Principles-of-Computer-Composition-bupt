-- --------------------------------------------------------------------
-- �ļ��� order_final.vhd                              ˳��Ӳ���߿�����
-- --------------------------------------------------------------------

-- ����
-- ��Ŀһ������Altera CPM7128��Ӳ���߿�������ư��ո������ݸ�ʽ��ָ��ϵͳ������ͨ·��
--         �������ṩ������Ҫ���������һ������Ӳ���߿�������˳��ģ�ʹ����
-- �������ܣ�������Ʒ�������TEC-8�Ͻ�����װ���������� 
-- ���ӹ��ܣ�
-- a.��ԭָ�������Ҫ����ָ��������
-- b.�޸�PCָ�빦�ܣ�����ָ�룩

-- --------------------------------------------------------------------
-- �汾����	v1.0 	2022.8.31
-- --------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
ENTITY controller IS
	PORT(
	--����
	SWC:in std_logic;--ģ�Ϳ���
	SWB:in std_logic;
	SWA:in std_logic;
	W3:in std_logic;--����
	W2:in std_logic;
	W1:in std_logic;
	CLR:in std_logic;--�����ź�
	T3:in std_logic;--�������������壬�����������彫��tec-8ʵ��̨���Զ���������ź�����
	IRH:in std_logic_vector(3 downto 0);--��������im7-im4
	C:in std_logic;--��λ��־
	Z:in std_logic;--���Ϊ0��־
	
	--���
	DRW:out std_logic;--����������д��RD1��RD0ѡ�еļĴ���
	PCINC:out std_logic;--PC�Լ�,SWCBA="000"ȡָʱ��Ч
	LPC:out std_logic;--SBUS->PC
	LAR:out std_logic;--SBUS->AR
	PCADD:out std_logic;--PC��ƫ������IR3-IR0��
	ARINC:out std_logic;--AR�Լ�
	SELCTL:out std_logic;--=1ʱ��A��B�˿ڼĴ����ֱ�ΪSEL3 SEL2��SEL1 SEL0ѡ�еļĴ���
	MEMW:out std_logic;--д�洢���ź�
	LIR:out std_logic;--ISN7-ISN0(˫�˿ڴ洢���Ҷ�)->IR
	LDZ:out std_logic;--���Ϊ0��־
	LDC:out std_logic;--��λ��־
	CIN:out std_logic;--ALU�ĵ�λ��λ�ź�
	S:out std_logic_vector(3 downto 0);--ALU�Ŀ����ź�
	M:out std_logic;--=1��ʾ�߼�����
	ABUS:out std_logic;--ALU->DBUS
	SBUS:out std_logic;--����->DBUS
	MBUS:out std_logic;--�洢��->DBUS
	SHORT:out std_logic;--ֻ��W1
	LONG:out std_logic;--W1��W2��W3
	SEL0:out std_logic;
	SEL1:out std_logic;
	SEL2:out std_logic;
	SEL3:out std_logic;
	STOP:out std_logic--ͣ��
	);
END controller ;
ARCHITECTURE exm OF controller IS
	signal ST0:std_logic; --һ��FLAG��=1��ʾ�ڶ��׶Σ���=1ʱW1��W2��ʾ�ڶ����Ľ׶ε�W1��W2Ҳ��W3��W4��
	signal SST0:std_logic;--��̬�ı���źţ�ָʾ��һ���ǵڼ����׶Σ�=1��ʾ��һ���ǵڶ����׶Ρ���ÿ�Ľ���ʱͨ�����SST0���ı�ST0��
	signal SWCBA:std_logic_vector(2 downto 0);
BEGIN
	SWCBA<=SWC & SWB & SWA;--����
	--�����ź�
	process(CLR,T3)
	begin
		if(T3'event and T3='0')THEN	--�½���
			if(SST0='1')THEN--���ָʾ��һ�׶ε��ź�
				ST0<='1';
			end if;
			if(W2='1' and SWCBA="100" and ST0='1')then--д�Ĵ������з�ֹѭ���ڶ��׶�	
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
		--��ʼ�����ź�
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
			when "100"=>--д�Ĵ���
				STOP<='1';
				SBUS<='1';
				SELCTL<='1';
				DRW<='1';
				SST0<=(not ST0) and W2;
				SEL3<=ST0;
				SEL2<=W2;
				SEL1<=((not ST0)and W1)or(ST0 and W2);
				SEL0<=W1;
			when "011"=>--���Ĵ���
				STOP<='1';
				SELCTL<='1';
				SEL3<=W2;
				SEL2<='0';
				SEL1<=W2;
				SEL0<='1';
			when "010"=>--���洢��
				SBUS<=(not ST0) and W1;
				LAR<=(not ST0) and W1;
				STOP<='1';
				SHORT<='1';
				SELCTL<='1';
				SST0<=(not ST0)and W1;
				MBUS<=ST0 and W1;
				ARINC<=ST0 and W1;
			when "001"=>--д�洢��
				SBUS<=W1;
				LAR<=(not ST0) and W1;
				STOP<='1';
				SHORT<='1';
				SELCTL<='1';
				SST0<=(not ST0)and W1;
				MEMW<=ST0 and W1;
				ARINC<=ST0 and W1;
			when "000"=>--ȡָ
				--��һ�׶��������׵�ַ
				SBUS<=(not ST0) and W1;
				LPC<=(not ST0) and W1;
				SST0<=(not ST0) and W1;
				SHORT<=(not ST0) and W1;
				STOP<=(not ST0);--������STOP<=(not ST0) and W1��W1�տ�ʼΪ0������ʹ����CLR��ͣ����
				--�����ǵڶ��׶Σ���һ�׶�ֻ��W1���ڶ��׶�W1��loadָ����PC�Լӡ�W2����ִ��ָ�
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
					when "1101"=>--����or
						M<=W2;
						S<="1110";
						ABUS<=W2;
						DRW<=W2;
						LDZ<=W2;
					when "1010"=>--����out-A
						M<=W2;
						S<="1111";
						ABUS<=W2;
					when "1100"=>--����MOV Rd Rs Rd<-Rs
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