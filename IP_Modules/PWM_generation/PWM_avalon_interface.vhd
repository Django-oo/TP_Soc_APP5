library ieee;
use ieee.std_logic_1164.all;

entity PWM_avalon_interface is
    port (
        clock        : in  std_logic;
        reset_n      : in  std_logic;

        address      : in  std_logic_vector(1 downto 0);
        read         : in  std_logic;
        write        : in  std_logic;
        chipselect   : in  std_logic;
        writedata    : in  std_logic_vector(15 downto 0);
        byteenable   : in  std_logic_vector(1 downto 0);
        readdata     : out std_logic_vector(15 downto 0);

        dc_motor_p_R : out std_logic;
        dc_motor_n_R : out std_logic;
        dc_motor_p_L : out std_logic;
        dc_motor_n_L : out std_logic
    );
end entity PWM_avalon_interface;

architecture rtl of PWM_avalon_interface is
    signal command_right : std_logic_vector(13 downto 0);
    signal command_left  : std_logic_vector(13 downto 0);
begin
    process(clock)
    begin
        if rising_edge(clock) then
            if reset_n = '0' then
                command_right <= (others => '0');
                command_left  <= (others => '0');
            elsif chipselect = '1' and write = '1' then
                case address is
                    when "00" =>
                        if byteenable(0) = '1' then
                            command_right(7 downto 0) <= writedata(7 downto 0);
                        end if;
                        if byteenable(1) = '1' then
                            command_right(13 downto 8) <= writedata(13 downto 8);
                        end if;

                    when "01" =>
                        if byteenable(0) = '1' then
                            command_left(7 downto 0) <= writedata(7 downto 0);
                        end if;
                        if byteenable(1) = '1' then
                            command_left(13 downto 8) <= writedata(13 downto 8);
                        end if;

                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process;

    process(address, read, chipselect, command_right, command_left)
    begin
        readdata <= (others => '0');

        if chipselect = '1' and read = '1' then
            case address is
                when "00" =>
                    readdata(13 downto 0) <= command_right;

                when "01" =>
                    readdata(13 downto 0) <= command_left;

                when "10" =>
                    readdata(0) <= command_right(13);
                    readdata(1) <= command_left(13);
                    readdata(2) <= command_right(12);
                    readdata(3) <= command_left(12);

                when others =>
                    readdata <= (others => '0');
            end case;
        end if;
    end process;

    pwm_core : entity work.PWM_generation
        port map (
            clk           => clock,
            reset_n       => reset_n,
            s_writedataR  => command_right,
            s_writedataL  => command_left,
            dc_motor_p_R  => dc_motor_p_R,
            dc_motor_n_R  => dc_motor_n_R,
            dc_motor_p_L  => dc_motor_p_L,
            dc_motor_n_L  => dc_motor_n_L
        );
end architecture rtl;
