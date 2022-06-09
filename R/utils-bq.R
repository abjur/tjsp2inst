#' Função para conectar com o Google Big Query
#'
#' Essa função conecta com o google big query
#'
#' @export
bq_connect <- function() {

  path_json <- system.file("bq.json", package = "tjsp2inst")
  bigrquery::bq_auth(path = path_json)

  con <- bigrquery::dbConnect(
    bigrquery::bigquery(),
    project = "abj-dev",
    dataset = "tjsp2inst",
    billing = "abj-dev"
  )

}
