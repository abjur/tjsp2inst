subir_bq <- function(da, nome) {
  da_subir <- da |>
    dplyr::mutate(dt_upload = Sys.Date())
  con <- bq_connect()
  bigrquery::dbWriteTable(
    con, nome,
    da_subir,
    overwrite = TRUE
    # append = TRUE # depende de como a gente vai estruturar as atualizações
  )
  bigrquery::dbDisconnect(con)
}
