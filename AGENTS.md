# Zifka — paquetes de datos firmados

## Inicio y alcance

- Leer `README.md` y los archivos afectados. Este repositorio publica paquetes; no contiene la app Valuation Suite ni autoriza cambios en su perímetro de fuentes.
- `data_feeds.json`: conservar el alcance revisado de cinco indicadores del Banco Mundial para seis mercados y metadatos de tickers SEC. FRED e IMF directos quedan excluidos incluso si existen credenciales o flags antiguos.
- `valuation_pack.json` es una referencia heredada sin revisión global de derechos; no extenderle la aprobación de `data_feeds.json`. Los paquetes regulatorios son independientes.
- Una firma acredita autenticidad, no permisos, actualidad, exactitud ni aprobación profesional. Las licencias de este repo no alteran derechos de las fuentes.

## Actualización y firma

- Preservar periodos de observación y `publishedAt` cuando solo se reempaqueta; no presentar ese cambio como actualización de datos.
- Una actualización real exitosa debe usar una versión estrictamente mayor a la vigente. Conservar evidencia de fuentes/licencias conforme al alcance indicado en `README.md`.
- Usar la identidad privada existente, guardada fuera del repo. Nunca incluir claves privadas en commits ni copiarlas/subirlas a servicios externos.
- Conservar la identidad pública fijada en `tool/test/feed_scope_test.dart` y el contrato con `SignedRulePackService.publicKeyHex` en la app; no rotar claves como arreglo editorial.
- Los clientes deben verificar firma y su propia lista de fuentes permitidas, conservando una base válida y acotada si falla la actualización.

## Comandos locales, según el cambio

Desde `tool/`:

- Dependencias/pruebas: `dart pub get`, `dart test`.
- Actualización: `dart run bin/refresh_feeds.dart ../data_feeds.json`.
- Firma: `dart run bin/sign_pack.dart <existing-private-key-path> ../data_feeds.json`.

La referencia al workflow semanal en `README.md` no autoriza activarlo: rige la instrucción global de trabajo local, sin GitHub Actions. Una edición documental no exige actualizar ni firmar paquetes.

## Cierre y conservación

- Rama `main`; preservar cambios ajenos. Preparar solo archivos revisados; todo commit lleva `[skip ci]`.
- Nunca copiar/subir `.env`, keystores, `key.properties`, llaves SSH, contraseñas o tokens a Git o servicios externos.
- Informar versión, fuentes realmente actualizadas, comprobaciones ejecutadas y pendientes; no atribuir a un reempaquetado una verificación que no ocurrió.
