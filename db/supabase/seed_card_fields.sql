-- Демо-значения полей карточки для первых 10 клиентов (применено к проекту crm-residencias).
-- Допустимые значения: config/crm_options.json
update public.clients c set
  situacion = v.situ, tipo_autorizacion = v.tipo, estado_expediente = v.estado,
  tipo_documento = v.doc, resultado_expediente = v.res, goal = v.goal, next_note = v.note
from (values
  (1031,'residencia_temporal','cuenta_ajena','requerimiento','tie_general','pendiente','Продлить ВНЖ без перерыва','Приложить новый padrón к ответу'),
  (1034,'residencia_circunstancias_excepcionales','arraigo_social','en_tramite','resguardo_solicitud','pendiente','Получить решение по укоренению','Ведомство молчит, проверить статус через 2 недели'),
  (1029,'residencia_temporal','cuenta_ajena','en_vigor','tie_general','pendiente','Подать на продление','Ждём документы от работодателя'),
  (1022,'residencia_temporal','cuenta_propia','en_vigor','tie_general','pendiente','Продление через 3 месяца',''),
  (1017,'residencia_larga_duracion','larga_duracion','en_vigor','tie_general','favorable','',''),
  (1038,'residencia_temporal','profesional_altamente_cualificado','en_tramite','resguardo_solicitud','pendiente','Модификация на высококвалифицированного специалиста',''),
  (1026,'residencia_temporal','no_lucrativa','en_tramite','tie_general','pendiente','Дождаться решения по продлению','Ответ на запрос отправлен'),
  (1011,'irregular',null,'pendiente_cita','pasaporte','pendiente','Восстановить легальный статус','Позвонить клиенту'),
  (1008,'residencia_temporal','reagrupacion_familiar','en_vigor','resolucion_favorable','favorable','','Решение получено, обновить срок'),
  (1040,'solicitud_proteccion_internacional',null,'requerimiento','doc_solicitante_proteccion','pendiente','Ответить на запрос ведомства','Срок ответа до 30.11')
) as v(num,situ,tipo,estado,doc,res,goal,note)
where c.num = v.num;

-- Гражданство и вымышленные NIE (контрольные буквы сходятся).
update public.clients c set nationality = v.nat, nie = v.nie
from (values
  (1031,'RU','X1234567L'),
  (1034,'RU','Y2345678Z'),
  (1029,'RU','X3456789G'),
  (1022,'UA','Z4567890A'),
  (1017,'RU','X5678901V'),
  (1038,'RU','Y6789012R'),
  (1026,'UA','X7890123L'),
  (1011,'RU','Z8901234D'),
  (1008,'RU','Y9012345Q'),
  (1040,'UA','X1122334A')
) as v(num,nat,nie)
where c.num = v.num;
