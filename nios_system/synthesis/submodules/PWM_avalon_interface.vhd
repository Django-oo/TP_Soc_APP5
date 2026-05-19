library ieee;
use ieee.std_logic_1164.all;

entity PWM_avalon_interface is
    port (
        clock        : in  std_logic;
        reset_n      : in  std_logic;

        address      : in  std_logic_vector(0 downto 0);
        chipselect   : in  std_logic;
        write        : in  std_logic;
        read         : in  std_logic;
        byteenable   : in  std_logic_vector(3 downto 0);
        writedata    : in  std_logic_vector(31 downto 0);
        readdata     : out std_logic_vector(31 downto 0);

        motor_out    : out std_logic_vector(3 downto 0)
    );
end entity PWM_avalon_interface;

architecture rtl of PWM_avalon_interface is
    signal command_right : std_logic_vector(13 downto 0) := (others => '0');
    signal command_left  : std_logic_vector(13 downto 0) := (others => '0');

    constant ZERO18 : std_logic_vector(17 downto 0) := (others => '0');
begin
    process(clock, reset_n)
    begin
        if reset_n = '0' then
            command_right <= (others => '0');
            command_left  <= (others => '0');
        elsif rising_edge(clock) then
            if chipselect = '1' and write = '1' then
                case address is
                    when "0" =>
                        if byteenable(0) = '1' then
                            command_right(7 downto 0) <= writedata(7 downto 0);
                        end if;
                        if byteenable(1) = '1' then
                            command_right(13 downto 8) <= writedata(13 downto 8);
                        end if;

                    when "1" =>
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

    readdata <= ZERO18 & command_right when address = "0" else
                ZERO18 & command_left;

    pwm_core : entity work.PWM_generation
        port map (
            clk           => clock,
            reset_n       => reset_n,
            command_right => command_right,
            command_left  => command_left,
            motor_out     => motor_out
        );
end architecture rtl;
