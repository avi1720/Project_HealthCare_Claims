-- =========================================================
-- CODE 1 : DIM_CLAIM_STATUS
-- =========================================================
 
create table if not exists Dim_Claim_Status as
 
select
    row_number() over(order by trim(claim_status))
    as Claim_Status_SK,
 
    Claim_Status
 
from
(
    select distinct Claim_Status
    from `01_silver_claims`.silver_claims
)t;
 
 
-- =========================================================
-- CODE 2 : DIM_DIAGNOSIS
-- =========================================================
 
create table if not exists Dim_Diagnosis as
 
select
    row_number() over(order by trim(diagnosis_code))
    as Diagnosis_SK,
 
    Diagnosis_Code
 
from
(
    select distinct Diagnosis_Code
    from `01_silver_claims`.silver_claims
)t;
 
 
-- =========================================================
-- CODE 3 : DIM_INSURANCE
-- =========================================================
 
create table if not exists Dim_Insurance as
 
select
    row_number() over(order by trim(insurance_provider))
    as Insurance_SK,
 
    Insurance_Provider
 
from
(
    select distinct Insurance_Provider
    from `01_silver_claims`.silver_claims
)t;
 
 
-- =========================================================
-- CODE 4 : DIM_DOCTOR
-- =========================================================
 
create table if not exists Dim_Doctor as
 
select
    row_number() over(order by trim(Doctor_ID))
    as Doctor_SK,
 
    Doctor_ID
 
from
(
    select distinct Doctor_ID
    from `01_silver_claims`.silver_claims
)t;
 
 
-- =========================================================
-- CODE 5 : DIM_PROCEDURE
-- =========================================================
 
create table if not exists Dim_Procedure as
 
select
    row_number() over(order by procedure_code)
    as Procedure_SK,
 
    procedure_code,
 
    procedure_description
 
from
(
    select distinct
        Procedure_Code,
        Procedure_Description
 
    from `01_silver_claims`.silver_claims
 
    where Procedure_Code is not null
      and Procedure_Description is not null
)t;
 
 
-- =========================================================
-- CODE 6 : DIM_PATIENT
-- =========================================================
 
create table if not exists Dim_Patient as
 
select
    row_number() over(order by trim(patient_id))
    as Patient_SK,
 
    Patient_ID
 
from
(
    select distinct Patient_ID
    from `01_silver_claims`.silver_claims
)t;
 
 
-- =========================================================
-- CODE 7 : DIM_HOSPITAL
-- =========================================================
 
create table if not exists Dim_Hospital as
 
select
    row_number() over(order by trim(Hospital_ID))
    as Hospital_SK,
 
    Hospital_ID
 
from
(
    select distinct Hospital_ID
    from `01_silver_claims`.silver_claims
)t;
 
 
-- =========================================================
-- CODE 8 : DIM_DATE
-- =========================================================
 
create table if not exists Dim_Date as
 
select distinct
 
    replace(admission_date,'-','') as Date_SK,
 
    Admission_Date as Full_Date,
 
    day(Admission_Date) as Day_Number,
 
    month(Admission_Date) as Month_Number,
 
    date_format(Admission_Date,'MMM') as Month_Name,
 
    quarter(Admission_Date) as Quarter_Number,
 
    year(Admission_Date) as Year_Number,
 
    date_format(Admission_Date,'EEEE') as Day_Name,
 
    case
        when weekday(admission_date) in (5,6)
        then 'Y'
        else 'N'
    end as Weekend_Flag
 
from `01_silver_claims`.silver_claims
 
union
 
select distinct
 
    replace(discharge_date,'-',''),
 
    Discharge_Date,
 
    day(Discharge_Date),
 
    month(Discharge_Date),
 
    date_format(Discharge_Date,'MMM'),
 
    quarter(Discharge_Date),
 
    year(Discharge_Date),
 
    date_format(Discharge_Date,'EEEE'),
 
    case
        when weekday(discharge_date) in (5,6)
        then 'Y'
        else 'N'
    end
 
from `01_silver_claims`.silver_claims;
 
 
-- =========================================================
-- CODE 9 : FACT_CLAIM_TRANSACTION
-- =========================================================
 
create table if not exists Fact_Claim_Transaction as
 
select
 
    s.Claim_ID,
    s.Line_Item_ID,
 
    dp.Patient_SK,
    dh.Hospital_SK,
    doc.Doctor_SK,
 
    dd.Diagnosis_SK,
 
    dpr.Procedure_SK,
 
    di.Insurance_SK,
 
    dcs.Claim_Status_SK,
 
    da.Date_SK as Admission_Date_SK,
 
    db.Date_SK as Discharge_Date_SK,
 
    s.Claim_Type,
 
    s.Payment_Method,
 
    s.Readmission_Flag,
 
    s.Quantity,
 
    s.Unit_Cost,
 
    s.Line_Amount
 
from `01_silver_claims`.silver_claims s
 
left join Dim_Patient dp
    on s.Patient_ID = dp.Patient_ID
 
left join Dim_Hospital dh
    on s.Hospital_ID = dh.Hospital_ID
 
left join Dim_Doctor doc
    on s.Doctor_ID = doc.Doctor_ID
 
left join Dim_Diagnosis dd
    on s.Diagnosis_Code = dd.Diagnosis_Code
 
left join Dim_Procedure dpr
    on s.Procedure_Code = dpr.Procedure_Code
 
left join Dim_Insurance di
    on s.Insurance_Provider = di.Insurance_Provider
 
left join Dim_Claim_Status dcs
    on s.Claim_Status = dcs.Claim_Status
 
left join Dim_Date da
    on s.Admission_Date = da.Full_Date
 
left join Dim_Date db
    on s.Discharge_Date = db.Full_Date;
 
 
-- =========================================================
-- CODE 10 : KPI_SUMMARY_CLAIMS
-- =========================================================
 
create table KPI_SUMMARY_CLAIMS as
 
select *
 
from
(
    select
        count(distinct Claim_ID) as Total_Claims,
        sum(Line_Amount) as Total_Revenue
    from Fact_Claim_Transaction
) Claim_Overview,
 
(
    select
        avg(Claim_Total) as Average_Claim_Amount
 
    from
    (
        select
            Claim_ID,
            sum(Line_Amount) as Claim_Total
 
        from Fact_Claim_Transaction
 
        group by Claim_ID
 
    ) Claim_Level_Revenue
 
) Claim_Amount_Analysis,
 
(
    select
 
        count(
            distinct case
 
                when Claim_Status_SK =
                (
                    select distinct Claim_Status_SK
                    from Dim_Claim_Status
                    where Claim_Status = 'Approved'
                )
 
                then Claim_ID
 
            end
        ) as Approved_Claims
 
    from Fact_Claim_Transaction
 
) Approved_Claim_Analysis,
 
(
    select
 
        count(
            distinct case
 
                when Claim_Status_SK in
                (
                    select Claim_Status_SK
                    from Dim_Claim_Status
                    where Claim_Status in
                    (
                        'Pending',
                        'In Progress',
                        'Partially Approved'
                    )
                )
 
                then Claim_ID
 
            end
        ) as Pending_Claims
 
    from Fact_Claim_Transaction
 
) Pending_Claim_Analysis,
 
(
    select
 
        count(
            distinct case
 
                when Claim_Status_SK in
                (
                    select Claim_Status_SK
                    from Dim_Claim_Status
                    where Claim_Status in
                    (
                        'Rejected',
                        'Declined'
                    )
                )
 
                then Claim_ID
 
            end
        ) as Rejected_Claims
 
    from Fact_Claim_Transaction
 
) Rejected_Claim_Analysis,
 
(
    select
 
        (Approved_Claims / Total_Claims) * 100
        as Approved_Claim_Rate
 
    from
    (
        select
 
            count(distinct Claim_ID)
            as Total_Claims,
 
            count(
                distinct case
 
                    when Claim_Status_SK =
                    (
                        select distinct Claim_Status_SK
                        from Dim_Claim_Status
                        where Claim_Status = 'Approved'
                    )
 
                    then Claim_ID
 
                end
            ) as Approved_Claims
 
        from Fact_Claim_Transaction
 
    ) Approval_Rate_Base
 
) Approval_Rate_Calculation,
 
(
    select
 
        count(distinct Claim_ID)
        as Readmission_Count
 
    from Fact_Claim_Transaction
 
    where Readmission_Flag = 'Yes'
 
) Readmission_Claim_Analysis,
 
(
    select
 
        (RDFlag / Total_Count) * 100
        as Readmission_Rate
 
    from
    (
        select
 
            count(distinct Claim_ID)
            as Total_Count,
 
            count(
                distinct case
 
                    when Readmission_Flag = 'Yes'
                    then Claim_ID
 
                end
            ) as RDFlag
 
        from Fact_Claim_Transaction
 
    ) Readmission_Rate_Base
 
) Readmission_Rate_Calculation,
 
(
    select
 
        avg(Quantity)
        as Avg_Quantity_Per_Claim
 
    from Fact_Claim_Transaction
 
) Quantity_Analysis;
 
 
-- =========================================================
-- CODE 11 : MONTHLY_CLAIMS_AGGREGATE
-- =========================================================
 
create table if not exists Monthly_Claims_Aggregate as
 
select
    d.Year_Number,
    d.Month_Number,
    d.Month_Name,
 
    count(distinct f.Claim_ID) as Total_Claims,
 
    sum(f.Line_Amount) as Total_Revenue,
 
    avg(claim_summary.Claim_Total) as Average_Claim_Amount,
 
    count(
        distinct case
            when cs.Claim_Status = 'Approved'
            then f.Claim_ID
        end
    ) as Approved_Claims,
 
    count(
        distinct case
            when cs.Claim_Status in
            (
                'Pending',
                'In Progress',
                'Partially Approved'
            )
            then f.Claim_ID
        end
    ) as Pending_Claims,
 
    count(
        distinct case
            when cs.Claim_Status in
            (
                'Rejected',
                'Declined'
            )
            then f.Claim_ID
        end
    ) as Rejected_Claims
 
from Fact_Claim_Transaction f
 
inner join Dim_Date d
    on f.Admission_Date_SK = d.Date_SK
 
inner join Dim_Claim_Status cs
    on f.Claim_Status_SK = cs.Claim_Status_SK
 
left join
(
    select
        Claim_ID,
        sum(Line_Amount) as Claim_Total
 
    from Fact_Claim_Transaction
 
    group by Claim_ID
 
) claim_summary
 
on f.Claim_ID = claim_summary.Claim_ID
 
group by
    d.Year_Number,
    d.Month_Number,
    d.Month_Name;
 
 
-- =========================================================
-- CODE 12 : HEALTH_CARE_DATAMART
-- =========================================================
 
create view Health_Care_DataMart as
 
select
 
    f.Claim_ID,
    f.Line_Item_ID,
 
    dp.Patient_ID,
 
    dh.Hospital_ID,
 
    doc.Doctor_ID,
 
    dd.Diagnosis_Code,
 
    dpr.Procedure_Code,
    dpr.Procedure_Description,
 
    di.Insurance_Provider,
 
    d.Claim_Status,
 
    da.Full_Date as Admission_Date,
 
    db.Full_Date as Discharge_Date,
 
    f.Claim_Type,
 
    f.Payment_Method,
 
    f.Readmission_Flag,
 
    f.Quantity,
 
    f.Unit_Cost,
 
    f.Line_Amount
 
from Fact_Claim_Transaction f
 
left join Dim_Claim_Status d
    on d.Claim_Status_SK = f.Claim_Status_SK
 
left join Dim_Date da
    on da.Date_SK = f.Admission_Date_SK
 
left join Dim_Date db
    on db.Date_SK = f.Discharge_Date_SK
 
left join Dim_Diagnosis dd
    on dd.Diagnosis_SK = f.Diagnosis_SK
 
left join Dim_Doctor doc
    on doc.Doctor_SK = f.Doctor_SK
 
left join Dim_Hospital dh
    on dh.Hospital_SK = f.Hospital_SK
 
left join Dim_Insurance di
    on di.Insurance_SK = f.Insurance_SK
 
left join Dim_Patient dp
    on dp.Patient_SK = f.Patient_SK
 
left join Dim_Procedure dpr
    on dpr.Procedure_SK = f.Procedure_SK;
