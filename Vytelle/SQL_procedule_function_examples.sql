--- example 01

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


--- example 02
CREATE DEFINER=`peng`@`%` FUNCTION `webui_deseret_2`.`fillInTrialValidDays`(
) RETURNS int
    READS SQL DATA
    DETERMINISTIC
BEGIN
    DECLARE finished int DEFAULT 0;
    DECLARE trialId int default null;
    DECLARE minValidDays int default null;
    DECLARE maxValidDays int default null;
    declare retval int default 0;

    -- declare cursor for employee email
    DEClARE trialListCursor
        CURSOR FOR
            select
                trial_id,
                min(validdays) as min_valid_days,
                max(validdays) as max_valid_days
                from (
                    select
                        trials.id as trial_id,
                        sum(if(pen_log.pen_check = 'OK', 1, 0)) as validdays
                        from trials, trial_pens, pens, pen_log
                        where trials.min_valid_days = 0
                            and trials.id = trial_pens.trial_id
                            and trial_pens.pen_id = pens.id
                            and trial_pens.pen_id = pen_log.pen_id
                            and pen_log.log_date >= date(trials.trial_start_date)
                            and pen_log.log_date <= date(trials.trial_end_date)
                        group by trials.id, trial_pens.pen_id) tb
                group by trial_id;

    -- declare NOT FOUND handler
    DECLARE CONTINUE HANDLER
        FOR NOT FOUND SET finished = 1;
    set @sqltext = '';

    OPEN trialListCursor;

    getTrial: LOOP
        FETCH trialListCursor INTO trialId, minValidDays, maxValidDays;
        IF finished = 1 THEN
            LEAVE getTrial;
        END IF;

        -- update trials info
        update trials
            set min_valid_days = minValidDays,
                max_valid_days = maxValidDays,
                min_invalid_days = progress_days - maxValidDays,
                max_invalid_days = progress_days - minValidDays,
                valid_days_range = maxValidDays - minValidDays + 1,
                invalid_days_range = maxValidDays - minValidDays + 1
            where trials.id = trialId;

        set retval = retval + row_count();
    END LOOP getTrial;
    CLOSE trialListCursor;

return retval;

end