# SARS2MOLIS

library(shiny)
library(stringr)
library(readxl)
library(cowplot)
library(DT)
library(tidyselect)
library(tidyverse)

shinyServer(function(input, output, session) {
    
    raw_data <- reactive({
        read_excel(input$pcr_file$datapath) %>%
            select(`File name`, `Creation date/time`, `Negative control ID`, `Sample ID`, `Channel No.`,
                   `Sample overall result (orig.)`, `Target result (orig.)`, `RFI`, `CT (orig.)`, `Channel result (orig.)`)
    })
    
    file <- reactive({raw_data()$`File name`[1]})
    date <- reactive({raw_data()$`Creation date/time`[1]})
    NC <- reactive({raw_data()$`Negative control ID`[1]})
   
    tidy_data <- reactive({
        raw_data() %>%
            select(-`File name`, -`Creation date/time`, -`Negative control ID`) %>%
            mutate(Ct = as.numeric(`CT (orig.)`)) %>%
            mutate(Target = ifelse(`Channel No.` == 2, "E_Gen", "IC")) %>%
            select(`Sample ID`, Target, Ct) %>%
            spread(key = Target, value = Ct) %>%
            mutate(Result = case_when(
                E_Gen < 45 ~ "Positiv",
                IC >= 25 & IC <= 40 & is.na(E_Gen) ~ "Negativ",
                TRUE ~ "Invalid")) %>%
            mutate(VL = signif(10^((E_Gen - 47.251)/-3.272),2)) %>%  #-3.272	47.251
            arrange(Result, `Sample ID`) %>%
            select(`Sample ID`, IC, E_Gen, VL, Result)
    })
  
    ### table
    output$results <- renderTable({
        tidy_data() 
    })

    ### Export
    molis_out <- reactive({
        table() %>% select(c("sample_name", "SARS_ct", "GAPDH_ct", "MS2_ct", "result", "flag"))
    })
    
   
    ### Download
    output$molis_export <- downloadHandler(
        
        filename = function() {
            paste0("molis-", Sys.Date(), ".txt")
        },
        
        content = function(file) {
            write.table(molis_out(),
                        file,
                        quote = FALSE,
                        sep ='\t',
                        row.names = FALSE,
                        eol = "\r\n",
                        append = FALSE)
        })
    
    output$pdf_export <- downloadHandler(
        
        filename = function() {
            from_molis <- if_else(molis_min() < 1000000000, true = molis_min()+1000000000, false = molis_min())
            to_molis <- if_else(molis_max() < 1000000000, true = molis_max()+1000000000, false = molis_max())
            
            paste0(from_molis, "_to_", to_molis, ".pdf")
        },
        
        content = function(file) {
            tempReport <- file.path(tempdir(), "report.Rmd")
            file.copy("report.Rmd", tempReport, overwrite = TRUE)
            
            params <- list(filename = input$pcr_file$name,
                           end_time = end_time_out(),
                           cycler_nr = cycler_nr_out(),
                           plot = plot_out(),
                           raw_data = raw_data(),
                           molis_out_table = molis_out(),
                           MS2_median = round(median(table()$MS2_ct_dbl, na.rm = TRUE), digits = 1),
                           MS2_sd = round(sd(table()$MS2_ct_dbl, na.rm = TRUE), digits = 3))
            
            rmarkdown::render(tempReport, output_file = file,
                              params = params,
                              envir = new.env(parent = globalenv()))
        })
})
