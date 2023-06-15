/*1. Print the name of the aircraft that have less than 50 seats?
     ====================================================================
     Выведите название самолетов, которые имеют менее 50 посадочных мест?*/

SELECT aircrafts.model AS "Название самолета",
       count(seats.seat_no) AS "Количество посадочных мест"
  FROM aircrafts
       INNER JOIN seats ON seats.aircraft_code = aircrafts.aircraft_code
 GROUP BY aircrafts.aircraft_code
HAVING count(seats.seat_no) < 50;

/*2. Print the percentage change in the monthly ticket booking amount, rounded to hundredths.
     ===========================================================================================
     Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.*/

SELECT date_trunc('MONTH', book_date)::date AS "Год и месяц бронирования",
       sum(total_amount) AS "Cумма бронирования",
       round(
             sum(total_amount) * 100 /
             LAG (
                  sum(total_amount)
                  ) OVER (ORDER BY date_trunc('MONTH', book_date)::date), 2
             ) - 100 AS "% изменения суммы" 
  FROM bookings
 GROUP BY date_trunc('MONTH', book_date)::date;

/*3. Print the names of aircraft that do not have business class. The solution should be via the array_agg function.
     =============================================================================================================== 
     Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.*/

SELECT model AS "Название самолета",
       array_agg(DISTINCT fare_conditions) AS "Класс"
  FROM aircrafts
       INNER JOIN seats ON seats.aircraft_code = aircrafts.aircraft_code
 GROUP BY model
HAVING array_agg(DISTINCT fare_conditions) && ARRAY ['Business'::varchar] IS FALSE;

/*4. Output a cumulative total of the number of seats in planes for each airport for each day, taking into account only those planes,
     which flew empty and only those days where more than one such aircraft took off from one airport.
     The result should be the airport code, date, number of empty seats and cumulative total.
     ================================================================================================================================
     Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, учитывая только те самолеты,
     которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.
     В результате должны быть код аэропорта, дата, количество пустых мест и накопительный итог.*/

-- solution 1:
-- решение 1:
   
SELECT "Код аэропорта",
       "Дата вылета",
       "Количество пустых мест",
       "Накопительный итог"
  FROM (
        SELECT departure_airport AS "Код аэропорта",
               date_trunc('DAY', actual_departure)::date AS "Дата вылета",
               count(seats.seat_no) AS "Количество пустых мест",
               sum(
                   count(seats.seat_no)
                   ) OVER (
                           PARTITION  BY departure_airport, date_trunc('DAY', actual_departure) 
                                ORDER BY actual_departure
                           ) AS "Накопительный итог",
               count(
                     flights.flight_id
                     ) OVER (
                             PARTITION  BY departure_airport, date_trunc('DAY', actual_departure)
                             ) AS count_flight_id
          FROM flights
               LEFT JOIN boarding_passes ON boarding_passes.flight_id = flights.flight_id
               LEFT JOIN aircrafts ON aircrafts.aircraft_code = flights.aircraft_code
               LEFT JOIN seats ON seats.aircraft_code = aircrafts.aircraft_code
         WHERE boarding_no IS NULL
           AND actual_departure IS NOT NULL
           AND status != 'Cancelled'
         GROUP BY flights.flight_id,
                  departure_airport,
                  date_trunc('DAY', actual_departure)
        ) AS preliminary_result
 WHERE count_flight_id > 1;
       
-- solution 2:
-- решение 2:
 
  WITH empty_planes AS (
                        SELECT flights.flight_id,
                               departure_airport, 
                               actual_departure,
                               aircraft_code,
                               count(
                                     flights.flight_id
                                     ) OVER (
                                             PARTITION  BY departure_airport, date_trunc('DAY', actual_departure)
                                             ) AS count_flight_id
                          FROM flights
                               LEFT JOIN boarding_passes ON boarding_passes.flight_id = flights.flight_id
                         WHERE boarding_no IS NULL
                           AND actual_departure IS NOT NULL
                           AND status != 'Cancelled'),
      quantity_seat AS (
                        SELECT aircrafts.aircraft_code,
                               count(seat_no) AS count_seat
                          FROM aircrafts
                               LEFT JOIN seats ON seats.aircraft_code = aircrafts.aircraft_code
                         GROUP BY aircrafts.aircraft_code)
SELECT departure_airport AS "Код аэропорта",
       date_trunc('DAY', actual_departure)::date AS "Дата вылета",
       count_seat AS "Количество пустых мест",
       sum(count_seat) OVER (
                             PARTITION  BY departure_airport, date_trunc('DAY', actual_departure) 
                                  ORDER BY actual_departure
                             ) AS "Накопительный итог"
  FROM empty_planes
       LEFT JOIN quantity_seat ON quantity_seat.aircraft_code = empty_planes.aircraft_code
 WHERE count_flight_id > 1;

/*5. Find the percentage of flights on routes from the total number of flights.
     As a result, print the names of airports and the percentage ratio.
     The solution should be through a window function.
     ====================================================================================
     Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
     Выведите в результат названия аэропортов и процентное отношение.
     Решение должно быть через оконную функцию.*/

SELECT departure_airport_name||' - '||arrival_airport_name AS "Маршрут",
       round(
             count(flights.flight_id) * 100 /
               sum(
                   count(flights.flight_id)
                   ) OVER (), 2
             ) AS "% от общего количества перелетов"
  FROM flights
       LEFT JOIN flights_v ON flights_v.flight_id = flights.flight_id       
 GROUP BY departure_airport_name,
          arrival_airport_name
 ORDER BY 1;

/*6. Print the number of passengers for each mobile operator code, given that the operator code is three characters after +7.
     =============================================================================================================================
     Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7.*/

SELECT count(passenger_id) AS "Количество пассажиров",
       substring(contact_data ->> 'phone', 3, 3) AS "Код оператора"
  FROM tickets
 GROUP BY substring(contact_data ->> 'phone', 3, 3)
 ORDER BY 2;

/*7. Classify financial turnover (the sum of the cost of tickets) by routes:
     Up to 50 million - low
     From 50 million inclusive to 150 million - middle
     From 150 million inclusive - high
     Output as a result the number of routes in each resulting class.
     ======================================================================== 
     Классифицируйте финансовые обороты (сумма стоимости билетов) по маршрутам:
     До 50 млн - low
     От 50 млн включительно до 150 млн - middle
     От 150 млн включительно - high
     Выведите в результат количество маршрутов в каждом полученном классе.*/
   
SELECT cost_class."class" AS "Класс",
       count(cost_class."class") AS "Количество маршрутов" 
  FROM (
        SELECT sum(amount),
               departure_airport,
               arrival_airport,
               CASE 
                    WHEN sum(amount) < 50000000 THEN 'low'
                    WHEN sum(amount) >= 50000000 AND sum(amount) < 150000000 THEN 'middle' 
                    ELSE 'high'
               END 
                    AS "class"
          FROM ticket_flights
               LEFT JOIN flights ON flights.flight_id = ticket_flights.flight_id
         GROUP BY departure_airport,
                  arrival_airport
        ) AS cost_class
 GROUP BY "class"        
 ORDER BY 2; 

/*8. Calculate the median ticket price, the median booking size, and the ratio of the median booking to the median ticket price, rounded to hundredths.
     ======================================================================================================================================================= 
     Вычислите медиану стоимости билетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости билетов, округленной до сотых.*/
      
  WITH median_cost AS (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount
                         FROM ticket_flights),
       median_total_cost AS (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY total_amount) AS median_total_amount
                               FROM bookings)
SELECT median_amount AS "Медиана стоимости билетов",
       median_total_amount AS "Медиана размера бронирования",
       round(
             (median_total_amount / median_amount)::numeric, 2
             ) AS "Отношение"
  FROM median_cost,
       median_total_cost;   
      
/*9. Find the value of the minimum flight cost of 1 km for passengers.
     That is, you need to find the distance between airports and, taking into account the cost of tickets, get the desired result.
     To find the distance between two points on the Earth's surface, you need to use an additional module
     earthdistance (https://postgrespro.ru/docs/postgresql/15/earthdistance).
     For this module to work, you need to install another cube module (https://postgrespro.ru/docs/postgresql/15/cube ). 
     The installation of additional modules takes place via the create extension module_name operator.
     The earth_distance function returns the result in meters.
     The modules are already installed in the cloud database.
     ============================================================================================================================== 
     Найдите значение минимальной стоимости полета 1 км для пассажиров.
     То есть нужно найти расстояние между аэропортами и с учетом стоимости билетов получить искомый результат.
     Для поиска расстояния между двумя точками на поверхности Земли нужно использовать дополнительный модуль
     earthdistance (https://postgrespro.ru/docs/postgresql/15/earthdistance).
     Для работы данного модуля нужно установить еще один модуль cube (https://postgrespro.ru/docs/postgresql/15/cube). 
     Установка дополнительных модулей происходит через оператор create extension название_модуля.
     Функция earth_distance возвращает результат в метрах.
     В облачной базе данных модули уже установлены.*/

CREATE EXTENSION CUBE;

CREATE EXTENSION earthdistance;

  WITH airport_departure AS (SELECT flight_id,
                                    longitude,
                                    latitude
                               FROM flights
                                    LEFT JOIN airports ON airports.airport_code = flights.departure_airport),
         airport_arrival AS (SELECT flight_id,
                                    longitude,
                                    latitude
                               FROM flights
                                    LEFT JOIN airports ON airports.airport_code = flights.arrival_airport)
SELECT DISTINCT min(
                    round(
                          amount / 
                          (
                           (
                            point(airport_departure.longitude, airport_departure.latitude) <@>
                            point (airport_arrival.longitude, airport_arrival.latitude)
                            ) * 1.61
                           )::numeric, 2
                          )
                    ) AS "Мин. цена 1 км. полета"
  FROM airport_departure
       LEFT JOIN airport_arrival ON airport_arrival.flight_id = airport_departure.flight_id
       LEFT JOIN ticket_flights ON ticket_flights.flight_id = airport_departure.flight_id
 WHERE amount IS NOT NULL;

