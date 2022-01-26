library(magrittr)

datas <- seq(as.Date("2021-01-01"), as.Date("2022-01-01"), by = 1)
path_cjsg <- "/mnt/dados/abj/tjsp/cjsg/2021/"
purrr::walk(datas, ~{
  dir_dia <- sprintf("%s%s", path_cjsg, as.character(.x))
  res <- ""
  if (!dir.exists(dir_dia)) {
    message(.x)
    safe <- purrr::possibly(lex::tjsp_cjsg_download, NULL)
    res <- safe("", dir_dia, julgamento_ini = .x, julgamento_fim = .x, sleep = 1)
  }
  res
})

## verificacao 1: pastas vazias
# arqs <- fs::dir_ls(
#   "/mnt/dados/abj/tjsp/cjsg/2021",
#   recurse = TRUE,
#   type = "file",
#   regexp = "pagina_"
# )
#
# tem_alguma_coisa <- unique(basename(dirname(arqs)))
# todos <- dir("/mnt/dados/abj/tjsp/cjsg/2021")
# nao_tem_nada <- setdiff(todos, tem_alguma_coisa)
# fs::dir_delete(paste0("/mnt/dados/abj/tjsp/cjsg/2021/", nao_tem_nada))

## verificacao 2: arquivos pequenos
# arqs <- fs::dir_ls(
#   "/mnt/dados/abj/tjsp/cjsg/2021",
#   recurse = TRUE,
#   type = "file",
#   regexp = "pagina_"
# )
# da_arqs <- fs::file_info(arqs)
# da_arqs %>%
#   dplyr::filter(size < 1000) %>%
#   with(path) %>%
#   dirname() %>%
#   unique() %>%
#   fs::dir_delete()
