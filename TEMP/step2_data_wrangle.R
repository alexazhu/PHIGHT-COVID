## This data wangling document is used to generate desired data variables and link data tables.
## Author: Ziyan Zhu, Cheyenne Ehman ## Updated on 08/01/2021


################### Load libraries ########################
library(tidyverse)
library(readxl)
library(ggplot2)
library(reshape2)

################### OH_K12 ###################
# read in OH_K12 data
OH_K12 <- read.csv("Data/Cleaned_Data/OH_K12_clean.csv")
OH_K12$opendategrouped <- as.Date(OH_K12$opendategrouped)

# compute number/percent of enrolled students in each school district by their adopted teaching posture 
enroll_by_teaching <- OH_K12 %>%
  distinct(county,teachingmethod,leaid,district_enroll,county_enroll)%>%
  group_by(county,teachingmethod, county_enroll)%>%
  summarise(total_teaching = sum(district_enroll),
            prop_teaching = round(sum(district_enroll/county_enroll),2),.groups = "drop")

# reshape the data frame to wide
wide_teaching_enroll <- enroll_by_teaching%>%
  dcast(county + county_enroll~teachingmethod,value.var ='prop_teaching')%>%
  replace(is.na(.),0)
  
# drop school districts whose teaching posture are UNKNOWN & PENDING & OTHER
wide_teaching_enroll <-  wide_teaching_enroll%>%
  select(-Unknown,-Other,-Pending)

# then find the teaching posture adopted by the majority of school districts in each county
# create a new column named 'major_teaching'
wide_teaching_enroll[,'major_teaching'] <- apply( wide_teaching_enroll[,3:5], 
                                                    1, function(x){names(which.max(x))})
  
# replace spaces in columns names with '_'
colnames( wide_teaching_enroll) <- gsub(' ','_',colnames( wide_teaching_enroll))

# made major teaching method prop
wide_teaching_enroll <- wide_teaching_enroll%>%
  mutate(major_teaching_prop = case_when(
    major_teaching=="Online Only" ~ Online_Only,
    major_teaching=="Hybrid" ~ Hybrid,
    major_teaching=="On Premises" ~On_Premises,
    TRUE~ 0
  ))




################## student mask ######################

# number of students & prop of students required to wear mask 
# at some point between 2020-2021
studentmask_enroll <- OH_K12 %>%
  distinct(county,leaid,studentmaskpolicy,district_enroll,county_enroll)%>%
  mutate(studentmaskpolicy = ifelse(studentmaskpolicy %in%c('Required for high school students only',"Required for middle/high school students only"),'Required for all students', studentmaskpolicy))%>%
  group_by(county,studentmaskpolicy,county_enroll)%>%
  summarise(n_studentmask = sum(district_enroll))

# #student in elementary schools from school districts where only require high/middle school students to wear mask
elementary_school_enroll <- OH_K12 %>%
  filter(studentmaskpolicy %in% c('Required for high school students only',"Required for middle/high school students only"))%>%
  filter(level == 1)%>%
  select(county,leaid,schnam,enrollment,studentmaskpolicy)%>%
  group_by(county)%>%
  summarise(elementary_enroll = sum(enrollment,na.rm=T),.groups = "drop")

# subtract above number
studentmask_enroll[(studentmask_enroll$studentmaskpolicy == 'Required for all students')&(studentmask_enroll$county %in% elementary_school_enroll$county),'n_studentmask'] <- studentmask_enroll[(studentmask_enroll$studentmaskpolicy == 'Required for all students')&(studentmask_enroll$county %in% elementary_school_enroll$county),'n_studentmask']-elementary_school_enroll$elementary_enroll

# calculate proportion
studentmask_enroll <- studentmask_enroll%>% 
  group_by(county,studentmaskpolicy,county_enroll)%>%
  mutate(prop_student_mask = round(n_studentmask/county_enroll,2))

# reshape the data frame
wide_studentmask_enroll <- studentmask_enroll%>%
  dcast(county~studentmaskpolicy,value.var ='prop_student_mask')
wide_studentmask_enroll [is.na(wide_studentmask_enroll )] <- 0

# remove unknown and pending
wide_studentmask_enroll <- wide_studentmask_enroll%>%
  select(-Unknown,-Pending)

colnames(wide_studentmask_enroll)[2] <- "Not required student"

# majority mask wearing
wide_studentmask_enroll[,'student_mask']<- apply(wide_studentmask_enroll[,2:3], 1, function(x){names(which.max(x))})


################## staff mask ######################
# we assume the number of staffs are proportionate to the number of students enrolled

# number of staff & prop of staff required to wear mask 
# at some point between 2020-2021

staffmask_enroll <- OH_K12 %>%
  distinct(county,staffmaskpolicy,leaid,district_enroll,county_enroll)%>%
  group_by(county,staffmaskpolicy,county_enroll)%>%
  summarise(n_staffmask = sum(district_enroll),prop_staff_mask = round(sum(district_enroll/county_enroll),2),.groups = "drop")

# reshape the data frame
wide_staffmask_enroll <- staffmask_enroll%>%
  dcast(county~staffmaskpolicy,value.var ='prop_staff_mask')
wide_staffmask_enroll[is.na(wide_staffmask_enroll )] <- 0

# remove unknown and pending
wide_staffmask_enroll <- wide_staffmask_enroll%>%
  select(-Unknown,-Pending)

colnames(wide_staffmask_enroll)[2] <- "Not required staff"

# majority staff mask
wide_staffmask_enroll[,'staff_mask']<- apply(wide_staffmask_enroll[,2:3], 1, function(x){names(which.max(x))})

################## school reopen date 'date' ######################
# not sure how opendategrouped is generated, lets use original 'date' 
# we notice that all school's in the same district have same reopen date

state_enroll <- OH_K12%>%
  distinct(county,county_enroll)%>%
  summarise(state_enroll=sum(county_enroll))

state_open_teaching_enroll <- OH_K12%>%
  mutate(state_enroll)%>%
  group_by(teachingmethod,date,state_enroll)%>%
  summarise(opendate_teaching_county_enroll = sum(district_enroll))%>%
  mutate(opendate = as.Date(date),opendate_teaching_state_prop = opendate_teaching_county_enroll/state_enroll)%>%
  select(-date)%>%
  distinct()

county_open_teaching_enroll <- OH_K12%>%
  distinct(county,leaid,teachingmethod,county_enroll,district_enroll,date)%>%
  group_by(county,date,teachingmethod)%>%
  summarise(open_county_enroll = sum(district_enroll),opendate_prop = sum(district_enroll)/county_enroll)%>%
  rename(opendate = date)

major_reopening <- county_open_teaching_enroll%>%
  group_by(county)%>%
  slice(which.max(opendate_prop))%>%
  rename(COUNTY=county,major_opendate=opendate)%>%
  distinct(COUNTY,major_opendate,opendate_prop)


################## OH CASES ######################

##########
ohio_profile <- read.csv("Data/RawData/county_level_latest_data_for_ohio.csv")
ohio_profile <- ohio_profile[,c(1,14:20,38:50)]
ohio_profile$County <- toupper(ohio_profile$County)

# read in OHIO_CASES_DATA
cases <- read_excel("Data/RawData/COVID_CASES_OH_CNTY_20210223_pop.xlsx")
# convert dates
cases$DATE <- as.Date(cases$DATE, "%m/%d/%Y")
# remove UNASSIGNED and OUT OF OH data
cases <- cases%>%
  filter( (COUNTY != 'UNASSIGNED') & (COUNTY !='OUT OF OH'))%>%
  mutate(FIPS = str_sub(UID,start = 4,end = 8))%>%
  select(COUNTY,FIPS,DATE,CNTY_LAT,CNTY_LONG,POPULATION,CUMCONFIRMED,CUMDEATHS,NEWDEATHS,NEWCONFIRMED)

##################### get mobility cured data ########################
library(covidcast)

parttime_work <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "part_time_work_prop_7dav",
                   start_day = "2020-01-22", end_day = "2021-02-22",
                   geo_type = "county", geo_values = c("39001", "39003", "39005", "39007", "39009", "39011", "39013", "39015", "39017", "39019", "39021", "39023", "39025", "39027", "39029", "39031", "39033", "39035", "39037", "39039", "39041", "39043", "39045", "39047", "39049", "39051", "39053", "39055", "39057", "39059", "39061", "39063", "39065", "39067", "39069", "39071", "39073", "39075", "39077", "39079", "39081", "39083", "39085", "39087", "39089", "39091", "39093", "39095", "39097", "39099", "39101", "39103", "39105", "39107", "39109", "39111", "39113", "39115", "39117", "39119", "39121", "39123", "39125", "39127", "39129", "39131", "39133", "39135", "39137", "39139", "39141", "39143", "39145", "39147", "39149", "39151", "39153", "39155", "39157", "39159", "39161", "39163", "39165", "39167", "39169", "39171", "39173", "39175"))
)

#Delphi receives data from SafeGraph, which collects anonymized location data from mobile phones. 
#Using this data, we calculate the fraction of mobile devices that spent more than 6 hours in one
#location other than their home during the daytime, and average it over a 7 day trailing window. 
#This indicator measures how mobile people are, and ought to reflect whether people are traveling 
#to work or school outside their homes. See also our "At Away Location 3-6hr" indicator.

fulltime_work <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "full_time_work_prop_7dav",
                   start_day = "2020-01-22", end_day = "2021-02-22",
                   geo_type = "county", geo_values = c("39001", "39003", "39005", "39007", "39009", "39011", "39013", "39015", "39017", "39019", "39021", "39023", "39025", "39027", "39029", "39031", "39033", "39035", "39037", "39039", "39041", "39043", "39045", "39047", "39049", "39051", "39053", "39055", "39057", "39059", "39061", "39063", "39065", "39067", "39069", "39071", "39073", "39075", "39077", "39079", "39081", "39083", "39085", "39087", "39089", "39091", "39093", "39095", "39097", "39099", "39101", "39103", "39105", "39107", "39109", "39111", "39113", "39115", "39117", "39119", "39121", "39123", "39125", "39127", "39129", "39131", "39133", "39135", "39137", "39139", "39141", "39143", "39145", "39147", "39149", "39151", "39153", "39155", "39157", "39159", "39161", "39163", "39165", "39167", "39169", "39171", "39173", "39175"))
)


restaurant <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "restaurants_visit_prop",
                   start_day = "2020-01-22", end_day = "2021-02-22",
                   geo_type = "county", geo_values = c("39001", "39003", "39005", "39007", "39009", "39011", "39013", "39015", "39017", "39019", "39021", "39023", "39025", "39027", "39029", "39031", "39033", "39035", "39037", "39039", "39041", "39043", "39045", "39047", "39049", "39051", "39053", "39055", "39057", "39059", "39061", "39063", "39065", "39067", "39069", "39071", "39073", "39075", "39077", "39079", "39081", "39083", "39085", "39087", "39089", "39091", "39093", "39095", "39097", "39099", "39101", "39103", "39105", "39107", "39109", "39111", "39113", "39115", "39117", "39119", "39121", "39123", "39125", "39127", "39129", "39131", "39133", "39135", "39137", "39139", "39141", "39143", "39145", "39147", "39149", "39151", "39153", "39155", "39157", "39159", "39161", "39163", "39165", "39167", "39169", "39171", "39173", "39175")))


bar <- suppressMessages(
  covidcast_signal(data_source = "safegraph", signal = "bars_visit_prop",
                   start_day = "2020-01-22", end_day = "2021-02-22",
                   geo_type = "county", geo_values = c("39001", "39003", "39005", "39007", "39009", "39011", "39013", "39015", "39017", "39019", "39021", "39023", "39025", "39027", "39029", "39031", "39033", "39035", "39037", "39039", "39041", "39043", "39045", "39047", "39049", "39051", "39053", "39055", "39057", "39059", "39061", "39063", "39065", "39067", "39069", "39071", "39073", "39075", "39077", "39079", "39081", "39083", "39085", "39087", "39089", "39091", "39093", "39095", "39097", "39099", "39101", "39103", "39105", "39107", "39109", "39111", "39113", "39115", "39117", "39119", "39121", "39123", "39125", "39127", "39129", "39131", "39133", "39135", "39137", "39139", "39141", "39143", "39145", "39147", "39149", "39151", "39153", "39155", "39157", "39159", "39161", "39163", "39165", "39167", "39169", "39171", "39173", "39175")))


mobility <- parttime_work%>%
  rename(part_work_prop_7d=value,part_work_std = stderr,part_work_sample_size=sample_size)%>%
  left_join(fulltime_work%>%
              rename(full_work_prop_7d=value,full_work_std = stderr,full_work_sample_size=sample_size,full_work_std = stderr),
            by = c("geo_value","time_value"))%>%
  left_join(restaurant%>%
              rename(res_visit_by_pop = value),by = c("geo_value","time_value"))%>%
  left_join(bar%>%
              rename(bar_visit_by_pop = value),by = c("geo_value","time_value"))%>%
  select(geo_value,time_value,part_work_prop_7d,part_work_sample_size,
         full_work_prop_7d,full_work_sample_size,full_work_std,
         res_visit_by_pop,bar_visit_by_pop)

#write.csv(mobility,"mobility.csv")










case_mobility <- mobility%>%
  inner_join(cases,by=c("geo_value"="FIPS","time_value"="DATE"))%>%
  rename(FIPS = geo_value,DATE = time_value,)

#write.csv(case_mobility,"case_mobility.csv")

date_mobility <- case_mobility%>%
  left_join(wide_teaching_enroll,by=c('COUNTY'='county'))%>%
  drop_na(major_teaching)%>%
  group_by(DATE,major_teaching)%>%
  summarise(full_work_prop = sum(full_work_prop_7d*POPULATION)/sum(POPULATION),
            part_work_prop = sum(part_work_prop_7d*POPULATION)/sum(POPULATION),
            res_visit_prop = sum(res_visit_by_pop),
            bar_visit_prop = sum(bar_visit_by_pop))
##################### calculate death prop ########################

# county-wise death proportions = cum deaths/population on 2021-02-22
death_prop <- case_mobility %>%
  filter(DATE == '2021-02-22')%>%
  mutate(death_prop = round(CUMDEATHS/POPULATION,5))%>%
  mutate(death_per_1000 = 1000*death_prop)

################### combine wide table ################### 
colnames(wide_teaching_enroll) <- gsub("\\ ","_",colnames(wide_teaching_enroll))
colnames(wide_studentmask_enroll) <- gsub("\\ ","_",colnames(wide_studentmask_enroll))
colnames(wide_staffmask_enroll) <- gsub("\\ ","_",colnames(wide_staffmask_enroll))

county_policy_wide <- wide_teaching_enroll%>%
  full_join(death_prop, by = c("county"= "COUNTY")) %>%
  full_join(wide_studentmask_enroll, by = c("county"))%>%
  full_join(wide_staffmask_enroll, by = c("county"))


county_policy_wide$major_teaching <- factor(county_policy_wide$major_teaching,
                                            levels = c("On Premises","Hybrid","Online Only"))

write.csv(county_policy_wide,"Cleaned_Data/county_policy_aggregate_wide.csv")

################### long table ################### 

long_teaching <- teachingmethod_enroll%>%
  left_join(death_prop,by = c("county"= "COUNTY"))

long_studentmask <- studentmask_enroll%>%
  left_join(death_prop,by = c("county"= "COUNTY"))

long_staff <- staffmask_enroll%>%
  left_join(death_prop,by = c("county"= "COUNTY"))

isonline_enroll <- enroll_by_teaching%>%
  filter(teachingmethod != 'Other'&teachingmethod != 'Pending'&teachingmethod != 'Unknown')%>%
  mutate(is_online = ifelse(teachingmethod == "Online Only","Online Only","Not Online Only"))%>%
  group_by(county,is_online) %>%
  summarise(prop_online_only = sum(prop_teachingmethod))%>%
  group_by(county)%>%
  slice(which.max(prop_online_only))

long_isonline <- isonline_enroll%>%
  left_join(death_prop,by=c('county'='COUNTY'))

long_isonline_mask <- long_studentmask%>%
  filter(!studentmaskpolicy%in%c('Pending','Unknown'))%>%
  group_by(county)%>%
  slice(which.max(prop_student_mask))%>%
  left_join(isonline_enroll,by=c('county'))

long_teaching_mask <- teachingmethod_enroll%>%
  filter(teachingmethod != 'Other'&teachingmethod != 'Pending'&teachingmethod != 'Unknown')%>%
  group_by(county)%>%
  slice(which.max(prop_teachingmethod))%>%
  left_join( long_studentmask%>%
               filter(!studentmaskpolicy%in%c('Pending','Unknown'))%>%
               group_by(county)%>%
               slice(which.max(prop_student_mask)),by=c('county','county_enroll'))



######## Valeries requested csv

library(reshape2)
newdeaths <- cases%>%
  select(COUNTY,NEWDEATHS,DATE)%>%
  drop_na(NEWDEATHS)%>%
  mutate(DATE = as.character(DATE))%>%
  dcast(COUNTY~DATE,value.var = "NEWDEATHS")

#write.csv(newdeaths,"newdeaths_ohio.csv",row.names = F)

cumdeaths <- cases%>%
  select(COUNTY,CUMDEATHS,DATE)%>%
  drop_na(CUMDEATHS)%>%
  mutate(DATE = as.character(DATE))%>%
  dcast(COUNTY~DATE,value.var = "CUMDEATHS")

#write.csv(cumdeaths,"cumdeaths_ohio.csv",row.names = F)

sixhrs_away <- case_mobility%>%
  select(COUNTY,DATE,full_work_prop_7d)%>%
  mutate(DATE = as.character(DATE))%>%
  dcast(COUNTY~DATE,value.var = "full_work_prop_7d")

#write.csv(sixhrs_away,"sixhrs_away.csv",row.names = F)

death_teaching <-  cases%>%
  full_join(wide_teaching_enroll, by = c("COUNTY"="county"))%>%
  select(COUNTY,DATE,POPULATION,CUMDEATHS,NEWDEATHS,Online_Only,Hybrid,On_Premises,major_teaching,major_teaching_prop)

death_teaching <- death_teaching%>%
  left_join(ohio_profile%>%distinct(County,Metropolitan.Status,NCHS.Urban.Rural.Status,Population.density),by=c("COUNTY"="County"))%>%
  left_join(major_reopening,by=c("COUNTY"))

#write.csv(death_teaching,"deaths_teaching.csv",row.names = F)


######## B(t) manipulation

# splines and slopes added
cases_slope <- read.csv("Data/Cleaned_Data/county_splines_slopes.csv", header = T)%>%
  select(COUNTY,DATE,POPULATION,CUMDEATHS,log_tot_deaths,tot.slope,NEWDEATHS,rev_NEWDEATHS,log_new_deaths,new.slope)

# SHIFT THE DATE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
cases_slope$DATE <- as.Date(cases_slope$DATE)-24

# get majority teaching method wide_teaching_enroll
cases_slope_teach <-death_teaching%>%
  select(-DATE,-POPULATION,-CUMDEATHS,-NEWDEATHS)%>%
  distinct()%>%
  right_join(cases_slope,by=c("COUNTY"))%>%
  filter(DATE>as.Date("2020-01-23"))

#write.csv(cases_slope_teach,"cases_slope_teach.csv",row.names = F)

## ordering the teaching method factor to ensure the color order

cases_slope_teach$major_teaching <- factor(cases_slope_teach$major_teaching,levels = c("On Premises","Hybrid","Online Only"))
cases_slope_teach$DATE <- as.Date(cases_slope_teach$DATE)


# Select Max B1 & B0

maxB1 <- cases_slope_teach%>%
  group_by(COUNTY)%>%
  filter(DATE >= as.Date("2020-08-18") & DATE<=as.Date("2020-12-15"))%>%
  summarise(max_B1 = max(new.slope))

avgB1 <- cases_slope_teach%>%
  group_by(COUNTY)%>%
  filter(DATE >= as.Date("2020-08-18") & DATE<=as.Date("2020-12-15"))%>%
  summarise(avg_B1 = mean(new.slope))

## avg3w_B0 ## average B0 of the first 3 weeks of school reopening 
## avg1w_2w_B0 ## OR average B0s between  2020-08-18 -7days and +14days [before the rate bounce back around the dashed line]
## avg3w_bf_B0 ## OR average B0s between  2020-08-18 -21days and 2020-08-18 [before the rate bounce back around the dashed line]
avgB0 <- cases_slope_teach%>%
  group_by(COUNTY)%>%
  filter(DATE > as.Date("2020-08-18") & DATE<as.Date(major_opendate)+21)%>%
  summarise(avg3w_B0 = mean(new.slope))%>%
  left_join(cases_slope_teach%>%
              group_by(COUNTY)%>%
              filter(DATE > as.Date("2020-08-18")-7 & DATE<as.Date("2020-08-18")+14)%>%
              summarise(avg1w_2w_B0 = mean(new.slope)),by="COUNTY")%>%
  left_join(cases_slope_teach%>%
              group_by(COUNTY)%>%
              filter(DATE < as.Date("2020-08-18") & DATE>=as.Date("2020-08-18")-21)%>%
              summarise(avg3w_bf_B0 = mean(new.slope)),by="COUNTY")

avg_mobility <- case_mobility%>%
  left_join(major_reopening,by=c("COUNTY"))%>%
  group_by(COUNTY)%>%
  #filter(DATE >= as.Date("2020-08-18")& DATE <as.Date("2020-08-18") + 21)%>%
  filter(DATE >= as.Date("2020-08-18")& DATE <= as.Date("2020-12-15"))%>%
  summarise(avg_full_work_prob = mean(full_work_prop_7d))%>%
  left_join(case_mobility%>%
              left_join(major_reopening,by=c("COUNTY"))%>%
              group_by(COUNTY)%>%
              filter(DATE >= as.Date("2020-08-18")+ 21 & DATE <=as.Date("2020-08-18") + 42)%>%
              summarise(avg2_full_work_prob = mean(full_work_prop_7d)),
            by="COUNTY")

#  B0 and B1
B0B1 <- death_teaching%>%
  distinct(COUNTY,POPULATION,NCHS.Urban.Rural.Status,Metropolitan.Status,Population.density)%>%
  left_join(maxB1,by="COUNTY")%>%
  left_join(wide_teaching_enroll, by = c("COUNTY" = "county"))%>%
  left_join(avgB1,by="COUNTY")%>%
  left_join(avgB0,by="COUNTY")%>%
  left_join(avg_mobility,by="COUNTY")

## ordering the teaching method factor to ensure the color order
B0B1$major_teaching <- factor(B0B1$major_teaching,levels = c("On Premises","Hybrid","Online Only"))


## shift mobility

# SHIFT the DATE for mobility as well: mobility a week ago may impact the infections number now
case_mobility$DATE <- case_mobility$DATE - 7 ## WARNING: only run this once
