#' Função para subir base no Goosle Big Query
#'
#' Essa função conecta com o google big query e escreve a
#' data base com um nome específico
#'
#' @param da base.
#' @param nome nome desejado.
#'
#' @export
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
