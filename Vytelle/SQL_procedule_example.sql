CREATE DEFINER=`peng`@`%` PROCEDURE `webui_deseret_2`.`animalIndividualWeightGraph_Animal`(
	animal_idx integer, 
	startDate date, 
	endDate date
)
BEGIN

	declare pen_idx int default lastPenView(animal_idx, endDate);

	declare trialFound bool; 

	call animalIndividualWeightHeader(animal_idx, startDate, endDate, trialFound);


	-- For date range, generate dates, max. 3800 days...

	-- Note: To send blank rows, join type = "left"
	-- To just send valid data, join type = "inner"
	-- This query joins 3 tables, if animal_log entry 
	-- is there, print the row, pen_log data isn't mandatory. 
	
	select
		FROM_DAYS(seq + TO_DAYS(startDate)) as logDate,
		if (trialFound, animal_log.current_weight, null) as animalWeight,
		(animal_log.avg_daily_gain) as averageDailyGain,
		animal_log.weight_14_days as weight14Days,
		(pen_log.day_14_avg_weight) as pens14DaysAvgWeight,
		(pen_log.avg_adg) as pensAvgADG,
		animal_flag as animalFlag
	FROM ((seq_0_to_3800 inner join animal_log
		on FROM_DAYS(seq + TO_DAYS(startDate)) = animal_log.log_date and
			animal_log.animal_id = animal_idx)
		left join pen_log on pen_idx = pen_log.pen_id and
			FROM_DAYS(seq + TO_DAYS(startDate)) = pen_log.log_date)
	WHERE FROM_DAYS(seq + TO_DAYS(startDate)) <= endDate;


END