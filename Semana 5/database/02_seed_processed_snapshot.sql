-- BancoXYZ Semana 5 - snapshot reproducible derivado de los 3 CSV legacy.
-- Las cuentas 101-108 y el estado anual 101/2024 se alinean con la evidencia funcional validada en Semana 5.
BEGIN;
TRUNCATE resumen_transacciones_diarias, transacciones_procesadas, estados_cuenta_anuales, cuentas_intereses RESTART IDENTITY;

COPY cuentas_intereses (cuenta_id,nombre,saldo_inicial,tipo,tasa_interes,interes_calculado,saldo_final,estado,observacion,activo,ultima_instancia_id) FROM STDIN;
101	John Doe	5000.00	ahorro	0.0100	50.00	5050.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
102	Jane Smith	8000.00	prestamo	0.0200	160.00	8160.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
103	Bob Johnson	12000.00	prestamo	0.0200	240.00	12240.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
104	Alice Brown	0.00	ahorro	0.0000	0.00	0.00	SIN_INTERES	Saldo igual a cero: no genera interés en el período	t	19
105	Charlie Green	7000.00	hipoteca	0.0000	0.00	7000.00	RECHAZADO	Tipo de cuenta no soportado para cálculo de intereses: hipoteca	t	19
106	John Doe	5000.00	ahorro	0.0100	50.00	5050.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
107	Diana Prince	15000.00	prestamo	0.0200	300.00	15300.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
108	Steve Rogers	10000.00	ahorro	0.0100	100.00	10100.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
109	John Doe	7000.00	prestamo	0.0200	140.00	7140.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
110	Charlie Green	10000.00	prestamo	0.0200	200.00	10200.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
111	John Doe	12000.00	prestamo	0.0200	240.00	12240.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
112	Jane Smith	10000.00	ahorro	0.0100	100.00	10100.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
113	Diana Prince	5000.00	ahorro	0.0100	50.00	5050.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
114	Unknown	8000.00	ahorro	0.0100	80.00	8080.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
115	Charlie Green	5000.00	prestamo	0.0200	100.00	5100.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
116	Diana Prince	7000.00	ahorro	0.0100	70.00	7070.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
117	Diana Prince	12000.00	prestamo	0.0200	240.00	12240.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
118	Jane Smith	12000.00	ahorro	0.0100	120.00	12120.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
119	John Doe	5000.00	prestamo	0.0200	100.00	5100.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
120	Charlie Green	7000.00	prestamo	0.0200	140.00	7140.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
121	Alice Brown	8000.00	ahorro	0.0100	80.00	8080.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
122	Steve Rogers	10000.00	ahorro	0.0100	100.00	10100.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
123	Bob Johnson	5000.00	ahorro	0.0100	50.00	5050.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
124	Jane Smith	10000.00	prestamo	0.0200	200.00	10200.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
125	Bob Johnson	7000.00	prestamo	0.0200	140.00	7140.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
126	John Doe	10000.00	prestamo	0.0200	200.00	10200.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
127	Jane Smith	8000.00	ahorro	0.0100	80.00	8080.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
128	Diana Prince	8000.00	ahorro	0.0100	80.00	8080.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
129	Alice Brown	5000.00	ahorro	0.0100	50.00	5050.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
130	Steve Rogers	5000.00	ahorro	0.0100	50.00	5050.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
131	Bob Johnson	10000.00	prestamo	0.0200	200.00	10200.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
132	Bob Johnson	5000.00	ahorro	0.0100	50.00	5050.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
133	Jane Smith	12000.00	prestamo	0.0200	240.00	12240.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
134	Steve Rogers	5000.00	prestamo	0.0200	100.00	5100.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
135	Bob Johnson	10000.00	prestamo	0.0200	200.00	10200.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
136	John Doe	10000.00	prestamo	0.0200	200.00	10200.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
137	Jane Smith	8000.00	ahorro	0.0100	80.00	8080.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
138	John Doe	7000.00	ahorro	0.0100	70.00	7070.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
139	Charlie Green	7000.00	prestamo	0.0200	140.00	7140.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
140	John Doe	7000.00	prestamo	0.0200	140.00	7140.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
141	Bob Johnson	5000.00	prestamo	0.0200	100.00	5100.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
142	Diana Prince	8000.00	prestamo	0.0200	160.00	8160.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
143	Steve Rogers	8000.00	prestamo	0.0200	160.00	8160.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
144	John Doe	7000.00	ahorro	0.0100	70.00	7070.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
145	Steve Rogers	12000.00	ahorro	0.0100	120.00	12120.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
146	Charlie Green	7000.00	ahorro	0.0100	70.00	7070.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
147	Steve Rogers	8000.00	ahorro	0.0100	80.00	8080.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
148	Charlie Green	12000.00	ahorro	0.0100	120.00	12120.00	PROCESADO	Interés mensual calculado con tasa de ahorro del 1%	t	19
149	Steve Rogers	8000.00	prestamo	0.0200	160.00	8160.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
150	Charlie Green	12000.00	prestamo	0.0200	240.00	12240.00	PROCESADO	Interés mensual calculado con tasa de préstamo del 2%	t	19
\.

COPY estados_cuenta_anuales (cuenta_id,anio,total_depositos,total_retiros,total_compras,saldo_anual,activo,ultima_instancia_id) FROM STDIN;
101	2024	1000.00	500.00	0.00	500.00	t	20
102	2024	24200.00	24400.00	23800.00	-24000.00	t	20
103	2024	12200.00	15500.00	42400.00	-45700.00	t	20
104	2024	17300.00	25800.00	28200.00	-36700.00	t	20
105	2024	27100.00	26200.00	19400.00	-18500.00	t	20
106	2024	30300.00	17000.00	40200.00	-26900.00	t	20
107	2024	28900.00	30200.00	23100.00	-24400.00	t	20
108	2024	18200.00	36300.00	22700.00	-40800.00	t	20
109	2024	40100.00	28600.00	14700.00	-3200.00	t	20
110	2024	18600.00	17900.00	20500.00	-19800.00	t	20
111	2024	31600.00	30100.00	18300.00	-16800.00	t	20
112	2024	30500.00	29700.00	20100.00	-19300.00	t	20
113	2024	24600.00	13600.00	19300.00	-8300.00	t	20
114	2024	25700.00	32000.00	32500.00	-38800.00	t	20
115	2024	18600.00	7300.00	28100.00	-16800.00	t	20
116	2024	40900.00	28600.00	31100.00	-18800.00	t	20
117	2024	26700.00	20200.00	17600.00	-11100.00	t	20
118	2024	33300.00	27100.00	30700.00	-24500.00	t	20
119	2024	24600.00	16600.00	36500.00	-28500.00	t	20
120	2024	20500.00	24600.00	16600.00	-20700.00	t	20
\.

COPY transacciones_procesadas (id,fecha,monto,tipo,estado,observacion,activo,ultima_instancia_id) FROM STDIN;
1	2024-06-30	3000.00	credito	PROCESADO	Transacción válida	t	21
2	2024-04-03	1200.00	credito	PROCESADO	Transacción válida	t	21
5	2024-06-17	800.00	debito	PROCESADO	Transacción válida	t	21
6	2024-11-11	1500.00	credito	PROCESADO	Transacción válida	t	21
8	2024-07-30	3000.00	debito	PROCESADO	Transacción válida	t	21
11	2024-10-05	1200.00	debito	PROCESADO	Transacción válida	t	21
12	2024-07-20	1200.00	debito	PROCESADO	Transacción válida	t	21
13	2024-04-13	3000.00	credito	PROCESADO	Transacción válida	t	21
14	2024-07-17	500.00	debito	PROCESADO	Transacción válida	t	21
18	2024-11-30	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
19	2024-08-16	800.00	credito	PROCESADO	Transacción válida	t	21
20	2024-07-28	3000.00	debito	PROCESADO	Transacción válida	t	21
21	2024-06-12	700.00	credito	PROCESADO	Transacción válida	t	21
26	2024-05-19	1200.00	debito	PROCESADO	Transacción válida	t	21
27	2024-12-11	1200.00	credito	PROCESADO	Transacción válida	t	21
33	2024-12-30	1500.00	credito	PROCESADO	Transacción válida	t	21
34	2024-11-13	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
35	2024-12-12	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
36	2024-07-25	1500.00	credito	PROCESADO	Transacción válida	t	21
37	2024-08-20	800.00	credito	PROCESADO	Transacción válida	t	21
38	2024-02-15	1500.00	debito	PROCESADO	Transacción válida	t	21
41	2024-08-01	800.00	credito	PROCESADO	Transacción válida	t	21
42	2024-07-29	500.00	credito	PROCESADO	Transacción válida	t	21
44	2024-07-11	1000.00	credito	PROCESADO	Transacción válida	t	21
46	2024-06-29	1200.00	debito	PROCESADO	Transacción válida	t	21
48	2024-08-09	1500.00	credito	PROCESADO	Transacción válida	t	21
49	2024-10-26	3000.00	debito	PROCESADO	Transacción válida	t	21
51	2024-07-02	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
55	2024-01-27	3000.00	credito	PROCESADO	Transacción válida	t	21
56	2024-09-06	1000.00	debito	PROCESADO	Transacción válida	t	21
58	2024-02-27	1000.00	credito	PROCESADO	Transacción válida	t	21
59	2024-02-08	800.00	credito	PROCESADO	Transacción válida	t	21
61	2024-01-09	3000.00	debito	PROCESADO	Transacción válida	t	21
62	2024-06-09	1000.00	credito	PROCESADO	Transacción válida	t	21
63	2024-08-14	700.00	credito	PROCESADO	Transacción válida	t	21
64	2024-03-13	1000.00	credito	PROCESADO	Transacción válida	t	21
67	2024-11-10	800.00	credito	PROCESADO	Transacción válida	t	21
71	2024-07-31	700.00	debito	PROCESADO	Transacción válida	t	21
73	2024-07-29	1000.00	credito	PROCESADO	Transacción válida	t	21
75	2024-01-28	1500.00	debito	PROCESADO	Transacción válida	t	21
76	2024-11-16	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
78	2024-11-25	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
82	2024-09-13	700.00	credito	PROCESADO	Transacción válida	t	21
83	2024-05-10	800.00	credito	PROCESADO	Transacción válida	t	21
84	2024-09-17	3000.00	debito	PROCESADO	Transacción válida	t	21
85	2024-03-16	1000.00	debito	PROCESADO	Transacción válida	t	21
88	2024-04-24	3000.00	credito	PROCESADO	Transacción válida	t	21
89	2024-07-27	800.00	debito	PROCESADO	Transacción válida	t	21
91	2024-01-01	800.00	credito	PROCESADO	Transacción válida	t	21
92	2024-01-27	1200.00	debito	PROCESADO	Transacción válida	t	21
93	2024-11-07	3000.00	debito	PROCESADO	Transacción válida	t	21
94	2024-08-01	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
95	2024-12-22	1000.00	credito	PROCESADO	Transacción válida	t	21
96	2024-12-18	800.00	credito	PROCESADO	Transacción válida	t	21
97	2024-08-17	500.00	debito	PROCESADO	Transacción válida	t	21
99	2024-03-09	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
101	2024-05-12	800.00	debito	PROCESADO	Transacción válida	t	21
102	2024-11-13	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
103	2024-04-02	1500.00	credito	PROCESADO	Transacción válida	t	21
104	2024-04-16	1000.00	credito	PROCESADO	Transacción válida	t	21
106	2024-01-21	1000.00	credito	PROCESADO	Transacción válida	t	21
110	2024-07-05	800.00	debito	PROCESADO	Transacción válida	t	21
111	2024-09-25	1000.00	credito	PROCESADO	Transacción válida	t	21
112	2024-03-07	800.00	credito	PROCESADO	Transacción válida	t	21
113	2024-07-21	1500.00	credito	PROCESADO	Transacción válida	t	21
115	2024-07-20	700.00	debito	PROCESADO	Transacción válida	t	21
117	2024-11-10	700.00	credito	PROCESADO	Transacción válida	t	21
120	2024-09-21	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
121	2024-08-19	700.00	debito	PROCESADO	Transacción válida	t	21
123	2024-05-27	3000.00	debito	PROCESADO	Transacción válida	t	21
125	2024-01-29	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
126	2024-03-11	800.00	debito	PROCESADO	Transacción válida	t	21
130	2024-07-24	1200.00	debito	PROCESADO	Transacción válida	t	21
131	2024-07-25	1000.00	debito	PROCESADO	Transacción válida	t	21
134	2024-04-06	800.00	credito	PROCESADO	Transacción válida	t	21
139	2024-09-16	700.00	debito	PROCESADO	Transacción válida	t	21
140	2024-08-22	1200.00	debito	PROCESADO	Transacción válida	t	21
141	2024-07-14	3000.00	debito	PROCESADO	Transacción válida	t	21
142	2024-11-19	3000.00	debito	PROCESADO	Transacción válida	t	21
143	2024-09-29	700.00	credito	PROCESADO	Transacción válida	t	21
144	2024-12-30	3000.00	debito	PROCESADO	Transacción válida	t	21
145	2024-01-01	1200.00	debito	PROCESADO	Transacción válida	t	21
147	2024-03-29	3000.00	credito	PROCESADO	Transacción válida	t	21
151	2024-12-18	3000.00	credito	PROCESADO	Transacción válida	t	21
153	2024-07-28	1000.00	credito	PROCESADO	Transacción válida	t	21
154	2024-03-04	800.00	credito	PROCESADO	Transacción válida	t	21
156	2024-03-02	1500.00	debito	PROCESADO	Transacción válida	t	21
157	2024-08-17	3000.00	debito	PROCESADO	Transacción válida	t	21
158	2024-05-26	500.00	debito	PROCESADO	Transacción válida	t	21
159	2024-09-01	1200.00	debito	PROCESADO	Transacción válida	t	21
161	2024-07-28	1500.00	credito	PROCESADO	Transacción válida	t	21
162	2024-12-11	3000.00	debito	PROCESADO	Transacción válida	t	21
166	2024-04-06	800.00	credito	PROCESADO	Transacción válida	t	21
168	2024-10-24	1200.00	credito	PROCESADO	Transacción válida	t	21
173	2024-08-24	100.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
177	2024-10-22	3000.00	debito	PROCESADO	Transacción válida	t	21
178	2024-05-17	3000.00	credito	PROCESADO	Transacción válida	t	21
179	2024-07-11	3000.00	credito	PROCESADO	Transacción válida	t	21
182	2024-03-02	800.00	credito	PROCESADO	Transacción válida	t	21
183	2024-01-21	3000.00	credito	PROCESADO	Transacción válida	t	21
184	2024-11-01	1500.00	debito	PROCESADO	Transacción válida	t	21
187	2024-05-25	800.00	debito	PROCESADO	Transacción válida	t	21
188	2024-03-15	500.00	debito	PROCESADO	Transacción válida	t	21
190	2024-07-26	1500.00	debito	PROCESADO	Transacción válida	t	21
192	2024-09-19	700.00	debito	PROCESADO	Transacción válida	t	21
194	2024-12-29	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
195	2024-06-13	800.00	debito	PROCESADO	Transacción válida	t	21
196	2024-08-08	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
197	2024-02-18	1200.00	credito	PROCESADO	Transacción válida	t	21
198	2024-12-04	800.00	debito	PROCESADO	Transacción válida	t	21
201	2024-11-15	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
204	2024-04-16	1200.00	debito	PROCESADO	Transacción válida	t	21
206	2024-11-20	3000.00	debito	PROCESADO	Transacción válida	t	21
207	2024-02-08	3000.00	debito	PROCESADO	Transacción válida	t	21
210	2024-02-09	700.00	debito	PROCESADO	Transacción válida	t	21
212	2024-04-23	1200.00	debito	PROCESADO	Transacción válida	t	21
213	2024-07-30	3000.00	debito	PROCESADO	Transacción válida	t	21
215	2024-03-01	1500.00	debito	PROCESADO	Transacción válida	t	21
217	2024-03-16	700.00	credito	PROCESADO	Transacción válida	t	21
218	2024-02-16	1200.00	credito	PROCESADO	Transacción válida	t	21
220	2024-08-28	500.00	credito	PROCESADO	Transacción válida	t	21
222	2024-03-10	100.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
223	2024-10-01	3000.00	credito	PROCESADO	Transacción válida	t	21
224	2024-12-20	500.00	credito	PROCESADO	Transacción válida	t	21
226	2024-04-29	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
227	2024-04-25	800.00	debito	PROCESADO	Transacción válida	t	21
233	2024-06-15	1000.00	debito	PROCESADO	Transacción válida	t	21
234	2024-07-03	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
236	2024-06-29	1000.00	debito	PROCESADO	Transacción válida	t	21
237	2024-02-21	1200.00	debito	PROCESADO	Transacción válida	t	21
238	2024-10-09	1200.00	credito	PROCESADO	Transacción válida	t	21
239	2024-03-04	800.00	debito	PROCESADO	Transacción válida	t	21
240	2024-06-17	3000.00	debito	PROCESADO	Transacción válida	t	21
241	2024-03-07	1000.00	credito	PROCESADO	Transacción válida	t	21
243	2024-10-17	800.00	debito	PROCESADO	Transacción válida	t	21
245	2024-06-02	800.00	credito	PROCESADO	Transacción válida	t	21
246	2024-02-10	1200.00	debito	PROCESADO	Transacción válida	t	21
250	2024-02-09	1200.00	debito	PROCESADO	Transacción válida	t	21
251	2024-07-14	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
252	2024-05-25	700.00	debito	PROCESADO	Transacción válida	t	21
255	2024-07-02	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
256	2024-04-22	1500.00	credito	PROCESADO	Transacción válida	t	21
257	2024-11-26	1000.00	credito	PROCESADO	Transacción válida	t	21
261	2024-06-26	500.00	debito	PROCESADO	Transacción válida	t	21
265	2024-12-16	3000.00	debito	PROCESADO	Transacción válida	t	21
268	2024-05-24	800.00	credito	PROCESADO	Transacción válida	t	21
274	2024-01-21	1500.00	credito	PROCESADO	Transacción válida	t	21
275	2024-08-09	700.00	credito	PROCESADO	Transacción válida	t	21
276	2024-10-16	700.00	debito	PROCESADO	Transacción válida	t	21
277	2024-08-12	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
278	2024-05-25	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
280	2024-07-27	1200.00	credito	PROCESADO	Transacción válida	t	21
281	2024-07-08	800.00	credito	PROCESADO	Transacción válida	t	21
284	2024-07-25	1500.00	credito	PROCESADO	Transacción válida	t	21
286	2024-09-27	800.00	credito	PROCESADO	Transacción válida	t	21
287	2024-11-17	800.00	debito	PROCESADO	Transacción válida	t	21
288	2024-09-03	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
289	2024-08-14	3000.00	debito	PROCESADO	Transacción válida	t	21
290	2024-06-15	1500.00	debito	PROCESADO	Transacción válida	t	21
292	2024-09-20	1000.00	credito	PROCESADO	Transacción válida	t	21
301	2024-10-03	1500.00	credito	PROCESADO	Transacción válida	t	21
303	2024-10-19	3000.00	credito	PROCESADO	Transacción válida	t	21
309	2024-03-23	1000.00	debito	PROCESADO	Transacción válida	t	21
321	2024-03-30	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
323	2024-07-27	700.00	credito	PROCESADO	Transacción válida	t	21
325	2024-03-22	700.00	debito	PROCESADO	Transacción válida	t	21
328	2024-11-10	1000.00	debito	PROCESADO	Transacción válida	t	21
331	2024-11-13	700.00	debito	PROCESADO	Transacción válida	t	21
332	2024-10-16	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
334	2024-08-16	3000.00	debito	PROCESADO	Transacción válida	t	21
335	2024-08-17	1000.00	debito	PROCESADO	Transacción válida	t	21
337	2024-10-08	3000.00	debito	PROCESADO	Transacción válida	t	21
340	2024-03-05	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
344	2024-10-21	700.00	credito	PROCESADO	Transacción válida	t	21
348	2024-07-13	1500.00	credito	PROCESADO	Transacción válida	t	21
349	2024-03-31	800.00	credito	PROCESADO	Transacción válida	t	21
350	2024-02-02	1200.00	debito	PROCESADO	Transacción válida	t	21
351	2024-08-31	1200.00	debito	PROCESADO	Transacción válida	t	21
355	2024-03-15	800.00	credito	PROCESADO	Transacción válida	t	21
356	2024-12-17	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
362	2024-11-06	1500.00	debito	PROCESADO	Transacción válida	t	21
364	2024-09-04	700.00	debito	PROCESADO	Transacción válida	t	21
365	2024-10-01	1200.00	credito	PROCESADO	Transacción válida	t	21
366	2024-07-22	700.00	debito	PROCESADO	Transacción válida	t	21
367	2024-03-14	1500.00	debito	PROCESADO	Transacción válida	t	21
368	2024-07-26	800.00	debito	PROCESADO	Transacción válida	t	21
370	2024-10-02	3000.00	debito	PROCESADO	Transacción válida	t	21
371	2024-12-10	1000.00	debito	PROCESADO	Transacción válida	t	21
372	2024-08-20	1200.00	debito	PROCESADO	Transacción válida	t	21
373	2024-09-30	800.00	debito	PROCESADO	Transacción válida	t	21
375	2024-12-02	1000.00	credito	PROCESADO	Transacción válida	t	21
376	2024-07-09	1200.00	credito	PROCESADO	Transacción válida	t	21
378	2024-05-19	800.00	credito	PROCESADO	Transacción válida	t	21
380	2024-12-26	1200.00	debito	PROCESADO	Transacción válida	t	21
390	2024-12-20	1200.00	credito	PROCESADO	Transacción válida	t	21
391	2024-09-09	500.00	credito	PROCESADO	Transacción válida	t	21
392	2024-04-10	1000.00	debito	PROCESADO	Transacción válida	t	21
394	2024-03-14	1500.00	credito	PROCESADO	Transacción válida	t	21
395	2024-07-09	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
397	2024-02-16	700.00	debito	PROCESADO	Transacción válida	t	21
399	2024-06-01	1500.00	credito	PROCESADO	Transacción válida	t	21
400	2024-07-03	1000.00	debito	PROCESADO	Transacción válida	t	21
401	2024-12-12	700.00	debito	PROCESADO	Transacción válida	t	21
403	2024-06-29	500.00	credito	PROCESADO	Transacción válida	t	21
405	2024-08-03	1500.00	credito	PROCESADO	Transacción válida	t	21
408	2024-12-30	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
409	2024-01-22	800.00	debito	PROCESADO	Transacción válida	t	21
411	2024-12-12	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
419	2024-01-19	800.00	credito	PROCESADO	Transacción válida	t	21
420	2024-05-30	1000.00	credito	PROCESADO	Transacción válida	t	21
421	2024-09-09	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
422	2024-09-09	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
424	2024-11-12	700.00	credito	PROCESADO	Transacción válida	t	21
426	2024-08-28	800.00	credito	PROCESADO	Transacción válida	t	21
428	2024-08-09	700.00	debito	PROCESADO	Transacción válida	t	21
432	2024-06-30	1000.00	debito	PROCESADO	Transacción válida	t	21
436	2024-08-21	100.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
439	2024-03-15	1200.00	credito	PROCESADO	Transacción válida	t	21
441	2024-12-04	1000.00	debito	PROCESADO	Transacción válida	t	21
442	2024-08-06	1200.00	debito	PROCESADO	Transacción válida	t	21
447	2024-02-08	1000.00	credito	PROCESADO	Transacción válida	t	21
449	2024-05-19	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
450	2024-03-07	1500.00	debito	PROCESADO	Transacción válida	t	21
452	2024-05-31	700.00	credito	PROCESADO	Transacción válida	t	21
454	2024-10-23	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
457	2024-03-26	1200.00	credito	PROCESADO	Transacción válida	t	21
458	2024-10-02	100.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
459	2024-01-31	1000.00	credito	PROCESADO	Transacción válida	t	21
463	2024-04-01	100.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
464	2024-07-24	1000.00	debito	PROCESADO	Transacción válida	t	21
465	2024-03-04	700.00	credito	PROCESADO	Transacción válida	t	21
467	2024-04-30	1500.00	credito	PROCESADO	Transacción válida	t	21
468	2024-03-17	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
477	2024-07-09	800.00	credito	PROCESADO	Transacción válida	t	21
480	2024-06-09	700.00	debito	PROCESADO	Transacción válida	t	21
481	2024-09-15	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
483	2024-11-07	1000.00	credito	PROCESADO	Transacción válida	t	21
484	2024-04-15	700.00	credito	PROCESADO	Transacción válida	t	21
487	2024-01-04	800.00	credito	PROCESADO	Transacción válida	t	21
489	2024-11-15	3000.00	debito	PROCESADO	Transacción válida	t	21
494	2024-11-26	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
495	2024-11-18	1500.00	credito	PROCESADO	Transacción válida	t	21
499	2024-05-16	1200.00	credito	PROCESADO	Transacción válida	t	21
502	2024-02-10	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
504	2024-09-16	500.00	credito	PROCESADO	Transacción válida	t	21
505	2024-07-08	1000.00	debito	PROCESADO	Transacción válida	t	21
508	2024-11-06	700.00	credito	PROCESADO	Transacción válida	t	21
509	2024-10-31	500.00	debito	PROCESADO	Transacción válida	t	21
510	2024-02-21	3000.00	credito	PROCESADO	Transacción válida	t	21
512	2024-08-14	700.00	credito	PROCESADO	Transacción válida	t	21
515	2024-07-14	700.00	debito	PROCESADO	Transacción válida	t	21
520	2024-09-02	1200.00	debito	PROCESADO	Transacción válida	t	21
521	2024-10-01	1500.00	credito	PROCESADO	Transacción válida	t	21
527	2024-05-17	1200.00	credito	PROCESADO	Transacción válida	t	21
529	2024-11-08	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
531	2024-01-07	700.00	credito	PROCESADO	Transacción válida	t	21
532	2024-10-15	3000.00	credito	PROCESADO	Transacción válida	t	21
533	2024-11-18	1500.00	credito	PROCESADO	Transacción válida	t	21
536	2024-09-30	700.00	credito	PROCESADO	Transacción válida	t	21
538	2024-08-22	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
539	2024-08-26	1500.00	debito	PROCESADO	Transacción válida	t	21
540	2024-04-18	800.00	credito	PROCESADO	Transacción válida	t	21
541	2024-06-22	3000.00	debito	PROCESADO	Transacción válida	t	21
544	2024-10-04	800.00	debito	PROCESADO	Transacción válida	t	21
545	2024-11-23	1000.00	debito	PROCESADO	Transacción válida	t	21
546	2024-04-26	1200.00	debito	PROCESADO	Transacción válida	t	21
547	2024-09-25	1200.00	credito	PROCESADO	Transacción válida	t	21
548	2024-08-17	1500.00	debito	PROCESADO	Transacción válida	t	21
550	2024-05-25	800.00	debito	PROCESADO	Transacción válida	t	21
553	2024-10-16	1500.00	debito	PROCESADO	Transacción válida	t	21
554	2024-06-29	1200.00	credito	PROCESADO	Transacción válida	t	21
555	2024-05-29	700.00	credito	PROCESADO	Transacción válida	t	21
556	2024-06-16	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
562	2024-01-19	800.00	credito	PROCESADO	Transacción válida	t	21
563	2024-08-17	1200.00	debito	PROCESADO	Transacción válida	t	21
564	2024-07-06	800.00	credito	PROCESADO	Transacción válida	t	21
566	2024-07-12	1200.00	debito	PROCESADO	Transacción válida	t	21
567	2024-01-15	700.00	credito	PROCESADO	Transacción válida	t	21
568	2024-03-11	1200.00	debito	PROCESADO	Transacción válida	t	21
571	2024-06-12	1200.00	debito	PROCESADO	Transacción válida	t	21
572	2024-11-05	3000.00	credito	PROCESADO	Transacción válida	t	21
573	2024-06-29	1200.00	credito	PROCESADO	Transacción válida	t	21
574	2024-10-18	3000.00	debito	PROCESADO	Transacción válida	t	21
575	2024-01-06	3000.00	debito	PROCESADO	Transacción válida	t	21
577	2024-02-17	800.00	debito	PROCESADO	Transacción válida	t	21
581	2024-01-21	3000.00	debito	PROCESADO	Transacción válida	t	21
585	2024-11-17	1200.00	debito	PROCESADO	Transacción válida	t	21
586	2024-01-31	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
587	2024-07-10	1200.00	credito	PROCESADO	Transacción válida	t	21
588	2024-11-22	1200.00	debito	PROCESADO	Transacción válida	t	21
589	2024-12-30	800.00	debito	PROCESADO	Transacción válida	t	21
590	2024-10-05	1500.00	credito	PROCESADO	Transacción válida	t	21
591	2024-08-10	3000.00	credito	PROCESADO	Transacción válida	t	21
592	2024-04-14	1500.00	credito	PROCESADO	Transacción válida	t	21
593	2024-03-05	1200.00	credito	PROCESADO	Transacción válida	t	21
597	2024-01-30	500.00	credito	PROCESADO	Transacción válida	t	21
602	2024-06-29	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
604	2024-05-15	1000.00	credito	PROCESADO	Transacción válida	t	21
607	2024-10-02	700.00	debito	PROCESADO	Transacción válida	t	21
608	2024-05-27	1000.00	debito	PROCESADO	Transacción válida	t	21
609	2024-11-14	3000.00	credito	PROCESADO	Transacción válida	t	21
612	2024-01-15	500.00	credito	PROCESADO	Transacción válida	t	21
613	2024-11-17	700.00	debito	PROCESADO	Transacción válida	t	21
618	2024-06-15	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
619	2024-09-30	1000.00	credito	PROCESADO	Transacción válida	t	21
620	2024-01-13	1000.00	credito	PROCESADO	Transacción válida	t	21
621	2024-03-23	1200.00	debito	PROCESADO	Transacción válida	t	21
623	2024-03-01	800.00	debito	PROCESADO	Transacción válida	t	21
624	2024-04-04	3000.00	credito	PROCESADO	Transacción válida	t	21
627	2024-12-29	700.00	credito	PROCESADO	Transacción válida	t	21
631	2024-09-16	1500.00	credito	PROCESADO	Transacción válida	t	21
633	2024-10-27	1500.00	debito	PROCESADO	Transacción válida	t	21
634	2024-06-15	1500.00	debito	PROCESADO	Transacción válida	t	21
636	2024-08-07	1500.00	credito	PROCESADO	Transacción válida	t	21
639	2024-09-26	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
640	2024-10-09	3000.00	debito	PROCESADO	Transacción válida	t	21
641	2024-11-29	1200.00	debito	PROCESADO	Transacción válida	t	21
642	2024-03-14	700.00	credito	PROCESADO	Transacción válida	t	21
646	2024-07-20	700.00	credito	PROCESADO	Transacción válida	t	21
647	2024-08-09	1000.00	debito	PROCESADO	Transacción válida	t	21
649	2024-04-16	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
650	2024-10-31	3000.00	credito	PROCESADO	Transacción válida	t	21
652	2024-04-28	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
653	2024-08-29	1500.00	debito	PROCESADO	Transacción válida	t	21
654	2024-04-16	800.00	debito	PROCESADO	Transacción válida	t	21
655	2024-01-14	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
656	2024-10-21	700.00	debito	PROCESADO	Transacción válida	t	21
659	2024-01-26	1000.00	credito	PROCESADO	Transacción válida	t	21
661	2024-06-27	1200.00	debito	PROCESADO	Transacción válida	t	21
662	2024-03-07	700.00	credito	PROCESADO	Transacción válida	t	21
667	2024-07-14	700.00	credito	PROCESADO	Transacción válida	t	21
669	2024-10-16	1500.00	debito	PROCESADO	Transacción válida	t	21
670	2024-12-07	1200.00	credito	PROCESADO	Transacción válida	t	21
673	2024-04-30	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
682	2024-01-22	700.00	credito	PROCESADO	Transacción válida	t	21
683	2024-03-03	500.00	credito	PROCESADO	Transacción válida	t	21
689	2024-06-22	1000.00	debito	PROCESADO	Transacción válida	t	21
690	2024-01-27	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
691	2024-02-09	800.00	debito	PROCESADO	Transacción válida	t	21
694	2024-04-06	1000.00	credito	PROCESADO	Transacción válida	t	21
700	2024-04-30	1000.00	debito	PROCESADO	Transacción válida	t	21
705	2024-10-16	700.00	credito	PROCESADO	Transacción válida	t	21
706	2024-03-20	1000.00	credito	PROCESADO	Transacción válida	t	21
707	2024-01-14	800.00	debito	PROCESADO	Transacción válida	t	21
708	2024-06-14	700.00	credito	PROCESADO	Transacción válida	t	21
710	2024-10-24	700.00	debito	PROCESADO	Transacción válida	t	21
723	2024-04-03	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
726	2024-10-10	1500.00	credito	PROCESADO	Transacción válida	t	21
727	2024-01-12	1000.00	debito	PROCESADO	Transacción válida	t	21
730	2024-03-18	800.00	debito	PROCESADO	Transacción válida	t	21
732	2024-11-11	1000.00	credito	PROCESADO	Transacción válida	t	21
734	2024-04-13	1500.00	credito	PROCESADO	Transacción válida	t	21
735	2024-09-23	1000.00	debito	PROCESADO	Transacción válida	t	21
740	2024-06-08	700.00	debito	PROCESADO	Transacción válida	t	21
743	2024-01-15	700.00	debito	PROCESADO	Transacción válida	t	21
744	2024-02-24	800.00	debito	PROCESADO	Transacción válida	t	21
747	2024-03-31	1000.00	credito	PROCESADO	Transacción válida	t	21
748	2024-10-06	800.00	credito	PROCESADO	Transacción válida	t	21
750	2024-03-03	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
753	2024-10-13	3000.00	debito	PROCESADO	Transacción válida	t	21
754	2024-09-01	1500.00	debito	PROCESADO	Transacción válida	t	21
756	2024-07-15	800.00	debito	PROCESADO	Transacción válida	t	21
757	2024-10-11	1000.00	credito	PROCESADO	Transacción válida	t	21
759	2024-03-31	1500.00	debito	PROCESADO	Transacción válida	t	21
760	2024-07-28	800.00	debito	PROCESADO	Transacción válida	t	21
761	2024-06-10	3000.00	debito	PROCESADO	Transacción válida	t	21
762	2024-08-15	1500.00	debito	PROCESADO	Transacción válida	t	21
764	2024-11-09	1000.00	credito	PROCESADO	Transacción válida	t	21
766	2024-04-11	1200.00	credito	PROCESADO	Transacción válida	t	21
767	2024-01-22	1500.00	credito	PROCESADO	Transacción válida	t	21
770	2024-08-27	1500.00	credito	PROCESADO	Transacción válida	t	21
774	2024-04-08	1000.00	credito	PROCESADO	Transacción válida	t	21
776	2024-07-13	800.00	credito	PROCESADO	Transacción válida	t	21
777	2024-01-25	3000.00	credito	PROCESADO	Transacción válida	t	21
778	2024-08-11	800.00	debito	PROCESADO	Transacción válida	t	21
779	2024-03-31	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
783	2024-02-28	1000.00	credito	PROCESADO	Transacción válida	t	21
787	2024-05-19	1000.00	credito	PROCESADO	Transacción válida	t	21
789	2024-05-27	1000.00	credito	PROCESADO	Transacción válida	t	21
790	2024-11-11	1000.00	credito	PROCESADO	Transacción válida	t	21
791	2024-06-28	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
795	2024-11-29	800.00	debito	PROCESADO	Transacción válida	t	21
797	2024-09-08	800.00	debito	PROCESADO	Transacción válida	t	21
798	2024-12-07	1000.00	debito	PROCESADO	Transacción válida	t	21
802	2024-02-29	1200.00	credito	PROCESADO	Transacción válida	t	21
807	2024-12-01	700.00	debito	PROCESADO	Transacción válida	t	21
808	2024-01-04	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
811	2024-07-24	1200.00	debito	PROCESADO	Transacción válida	t	21
814	2024-10-22	700.00	credito	PROCESADO	Transacción válida	t	21
818	2024-06-19	100.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
820	2024-08-12	3000.00	credito	PROCESADO	Transacción válida	t	21
822	2024-09-18	1200.00	credito	PROCESADO	Transacción válida	t	21
823	2024-01-28	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
824	2024-04-16	3000.00	credito	PROCESADO	Transacción válida	t	21
826	2024-10-15	500.00	debito	PROCESADO	Transacción válida	t	21
827	2024-02-06	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
830	2024-10-10	3000.00	debito	PROCESADO	Transacción válida	t	21
831	2024-08-03	1000.00	debito	PROCESADO	Transacción válida	t	21
832	2024-06-26	700.00	debito	PROCESADO	Transacción válida	t	21
833	2024-05-16	700.00	debito	PROCESADO	Transacción válida	t	21
834	2024-02-02	3000.00	credito	PROCESADO	Transacción válida	t	21
836	2024-06-08	1500.00	credito	PROCESADO	Transacción válida	t	21
839	2024-04-23	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
840	2024-08-12	800.00	debito	PROCESADO	Transacción válida	t	21
842	2024-10-30	1500.00	credito	PROCESADO	Transacción válida	t	21
843	2024-03-12	1500.00	credito	PROCESADO	Transacción válida	t	21
844	2024-11-23	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
847	2024-10-14	1000.00	debito	PROCESADO	Transacción válida	t	21
848	2024-06-07	1200.00	credito	PROCESADO	Transacción válida	t	21
849	2024-05-01	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
850	2024-12-20	3000.00	credito	PROCESADO	Transacción válida	t	21
854	2024-06-27	500.00	debito	PROCESADO	Transacción válida	t	21
855	2024-08-20	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
856	2024-07-22	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
857	2024-10-29	800.00	debito	PROCESADO	Transacción válida	t	21
859	2024-04-08	3000.00	debito	PROCESADO	Transacción válida	t	21
861	2024-09-13	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
865	2024-05-29	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
866	2024-02-08	800.00	debito	PROCESADO	Transacción válida	t	21
869	2024-09-26	3000.00	credito	PROCESADO	Transacción válida	t	21
871	2024-07-27	3000.00	debito	PROCESADO	Transacción válida	t	21
872	2024-04-01	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
876	2024-06-27	700.00	credito	PROCESADO	Transacción válida	t	21
880	2024-01-14	800.00	credito	PROCESADO	Transacción válida	t	21
884	2024-01-08	800.00	credito	PROCESADO	Transacción válida	t	21
885	2024-05-29	1000.00	debito	PROCESADO	Transacción válida	t	21
886	2024-12-27	1200.00	debito	PROCESADO	Transacción válida	t	21
887	2024-02-19	3000.00	credito	PROCESADO	Transacción válida	t	21
889	2024-10-10	1500.00	debito	PROCESADO	Transacción válida	t	21
890	2024-02-29	3000.00	debito	PROCESADO	Transacción válida	t	21
892	2024-06-05	500.00	debito	PROCESADO	Transacción válida	t	21
895	2024-11-04	1500.00	credito	PROCESADO	Transacción válida	t	21
897	2024-05-04	3000.00	credito	PROCESADO	Transacción válida	t	21
898	2024-12-12	500.00	debito	PROCESADO	Transacción válida	t	21
899	2024-12-14	1500.00	credito	PROCESADO	Transacción válida	t	21
900	2024-01-19	1000.00	debito	PROCESADO	Transacción válida	t	21
903	2024-10-29	1500.00	debito	PROCESADO	Transacción válida	t	21
904	2024-05-28	700.00	debito	PROCESADO	Transacción válida	t	21
905	2024-02-11	1000.00	debito	PROCESADO	Transacción válida	t	21
907	2024-05-29	1200.00	debito	PROCESADO	Transacción válida	t	21
908	2024-02-27	700.00	debito	PROCESADO	Transacción válida	t	21
911	2024-09-29	700.00	debito	PROCESADO	Transacción válida	t	21
912	2024-10-10	1000.00	debito	PROCESADO	Transacción válida	t	21
914	2024-07-09	700.00	credito	PROCESADO	Transacción válida	t	21
919	2024-05-31	1500.00	credito	PROCESADO	Transacción válida	t	21
920	2024-05-30	800.00	debito	PROCESADO	Transacción válida	t	21
922	2024-04-29	1200.00	debito	PROCESADO	Transacción válida	t	21
929	2024-07-06	800.00	debito	PROCESADO	Transacción válida	t	21
930	2024-01-17	800.00	credito	PROCESADO	Transacción válida	t	21
932	2024-11-22	1500.00	debito	PROCESADO	Transacción válida	t	21
936	2024-06-11	1500.00	credito	PROCESADO	Transacción válida	t	21
937	2024-03-07	500.00	debito	PROCESADO	Transacción válida	t	21
939	2024-04-20	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
940	2024-12-09	1000.00	credito	PROCESADO	Transacción válida	t	21
942	2024-03-15	1500.00	credito	PROCESADO	Transacción válida	t	21
943	2024-02-19	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
945	2024-08-13	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
946	2024-06-04	3000.00	credito	PROCESADO	Transacción válida	t	21
948	2024-07-24	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
950	2024-10-14	1000.00	debito	PROCESADO	Transacción válida	t	21
952	2024-11-30	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
953	2024-06-23	3000.00	credito	PROCESADO	Transacción válida	t	21
955	2024-01-02	700.00	credito	PROCESADO	Transacción válida	t	21
958	2024-07-25	1200.00	credito	PROCESADO	Transacción válida	t	21
962	2024-08-11	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
963	2024-10-25	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
964	2024-07-27	1200.00	debito	PROCESADO	Transacción válida	t	21
966	2024-09-19	3000.00	credito	PROCESADO	Transacción válida	t	21
967	2024-06-22	500.00	credito	PROCESADO	Transacción válida	t	21
968	2024-05-05	100.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
971	2024-03-04	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
974	2024-08-02	1200.00	debito	PROCESADO	Transacción válida	t	21
979	2024-11-22	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
981	2024-01-20	200.00	debito	CORREGIDO	Monto negativo de debito normalizado a valor absoluto	t	21
985	2024-09-06	700.00	credito	PROCESADO	Transacción válida	t	21
989	2024-08-22	800.00	debito	PROCESADO	Transacción válida	t	21
990	2024-04-27	1500.00	debito	PROCESADO	Transacción válida	t	21
992	2024-03-15	1000.00	credito	PROCESADO	Transacción válida	t	21
995	2024-02-08	200.00	credito	CORREGIDO	Monto negativo de credito normalizado a valor absoluto	t	21
996	2024-07-23	700.00	debito	PROCESADO	Transacción válida	t	21
999	2024-06-19	1500.00	debito	PROCESADO	Transacción válida	t	21
1000	2024-12-30	1500.00	credito	PROCESADO	Transacción válida	t	21
\.

COPY resumen_transacciones_diarias (fecha,cantidad_transacciones,total_creditos,total_debitos,saldo_neto,ultima_instancia_id) FROM STDIN;
2024-01-01	2	800.00	1200.00	-400.00	21
2024-01-02	1	700.00	0.00	700.00	21
2024-01-04	2	800.00	200.00	600.00	21
2024-01-06	1	0.00	3000.00	-3000.00	21
2024-01-07	1	700.00	0.00	700.00	21
2024-01-08	1	800.00	0.00	800.00	21
2024-01-09	1	0.00	3000.00	-3000.00	21
2024-01-12	1	0.00	1000.00	-1000.00	21
2024-01-13	1	1000.00	0.00	1000.00	21
2024-01-14	3	1000.00	800.00	200.00	21
2024-01-15	3	1200.00	700.00	500.00	21
2024-01-17	1	800.00	0.00	800.00	21
2024-01-19	3	1600.00	1000.00	600.00	21
2024-01-20	1	0.00	200.00	-200.00	21
2024-01-21	4	5500.00	3000.00	2500.00	21
2024-01-22	3	2200.00	800.00	1400.00	21
2024-01-25	1	3000.00	0.00	3000.00	21
2024-01-26	1	1000.00	0.00	1000.00	21
2024-01-27	3	3000.00	1400.00	1600.00	21
2024-01-28	2	0.00	1700.00	-1700.00	21
2024-01-29	1	200.00	0.00	200.00	21
2024-01-30	1	500.00	0.00	500.00	21
2024-01-31	2	1200.00	0.00	1200.00	21
2024-02-02	2	3000.00	1200.00	1800.00	21
2024-02-06	1	0.00	200.00	-200.00	21
2024-02-08	5	2000.00	3800.00	-1800.00	21
2024-02-09	3	0.00	2700.00	-2700.00	21
2024-02-10	2	100.00	1200.00	-1100.00	21
2024-02-11	1	0.00	1000.00	-1000.00	21
2024-02-15	1	0.00	1500.00	-1500.00	21
2024-02-16	2	1200.00	700.00	500.00	21
2024-02-17	1	0.00	800.00	-800.00	21
2024-02-18	1	1200.00	0.00	1200.00	21
2024-02-19	2	3200.00	0.00	3200.00	21
2024-02-21	2	3000.00	1200.00	1800.00	21
2024-02-24	1	0.00	800.00	-800.00	21
2024-02-27	2	1000.00	700.00	300.00	21
2024-02-28	1	1000.00	0.00	1000.00	21
2024-02-29	2	1200.00	3000.00	-1800.00	21
2024-03-01	2	0.00	2300.00	-2300.00	21
2024-03-02	2	800.00	1500.00	-700.00	21
2024-03-03	2	500.00	200.00	300.00	21
2024-03-04	4	1700.00	800.00	900.00	21
2024-03-05	2	1200.00	200.00	1000.00	21
2024-03-07	5	2500.00	2000.00	500.00	21
2024-03-09	1	200.00	0.00	200.00	21
2024-03-10	1	0.00	100.00	-100.00	21
2024-03-11	2	0.00	2000.00	-2000.00	21
2024-03-12	1	1500.00	0.00	1500.00	21
2024-03-13	1	1000.00	0.00	1000.00	21
2024-03-14	3	2200.00	1500.00	700.00	21
2024-03-15	5	4500.00	500.00	4000.00	21
2024-03-16	2	700.00	1000.00	-300.00	21
2024-03-17	1	0.00	200.00	-200.00	21
2024-03-18	1	0.00	800.00	-800.00	21
2024-03-20	1	1000.00	0.00	1000.00	21
2024-03-22	1	0.00	700.00	-700.00	21
2024-03-23	2	0.00	2200.00	-2200.00	21
2024-03-26	1	1200.00	0.00	1200.00	21
2024-03-29	1	3000.00	0.00	3000.00	21
2024-03-30	1	0.00	200.00	-200.00	21
2024-03-31	4	1800.00	1700.00	100.00	21
2024-04-01	2	0.00	300.00	-300.00	21
2024-04-02	1	1500.00	0.00	1500.00	21
2024-04-03	2	1200.00	200.00	1000.00	21
2024-04-04	1	3000.00	0.00	3000.00	21
2024-04-06	3	2600.00	0.00	2600.00	21
2024-04-08	2	1000.00	3000.00	-2000.00	21
2024-04-10	1	0.00	1000.00	-1000.00	21
2024-04-11	1	1200.00	0.00	1200.00	21
2024-04-13	2	4500.00	0.00	4500.00	21
2024-04-14	1	1500.00	0.00	1500.00	21
2024-04-15	1	700.00	0.00	700.00	21
2024-04-16	5	4000.00	2200.00	1800.00	21
2024-04-18	1	800.00	0.00	800.00	21
2024-04-20	1	0.00	200.00	-200.00	21
2024-04-22	1	1500.00	0.00	1500.00	21
2024-04-23	2	200.00	1200.00	-1000.00	21
2024-04-24	1	3000.00	0.00	3000.00	21
2024-04-25	1	0.00	800.00	-800.00	21
2024-04-26	1	0.00	1200.00	-1200.00	21
2024-04-27	1	0.00	1500.00	-1500.00	21
2024-04-28	1	0.00	200.00	-200.00	21
2024-04-29	2	0.00	1400.00	-1400.00	21
2024-04-30	3	1700.00	1000.00	700.00	21
2024-05-01	1	0.00	200.00	-200.00	21
2024-05-04	1	3000.00	0.00	3000.00	21
2024-05-05	1	100.00	0.00	100.00	21
2024-05-10	1	800.00	0.00	800.00	21
2024-05-12	1	0.00	800.00	-800.00	21
2024-05-15	1	1000.00	0.00	1000.00	21
2024-05-16	2	1200.00	700.00	500.00	21
2024-05-17	2	4200.00	0.00	4200.00	21
2024-05-19	4	2000.00	1200.00	800.00	21
2024-05-24	1	800.00	0.00	800.00	21
2024-05-25	4	0.00	2500.00	-2500.00	21
2024-05-26	1	0.00	500.00	-500.00	21
2024-05-27	3	1000.00	4000.00	-3000.00	21
2024-05-28	1	0.00	700.00	-700.00	21
2024-05-29	4	900.00	2200.00	-1300.00	21
2024-05-30	2	1000.00	800.00	200.00	21
2024-05-31	2	2200.00	0.00	2200.00	21
2024-06-01	1	1500.00	0.00	1500.00	21
2024-06-02	1	800.00	0.00	800.00	21
2024-06-04	1	3000.00	0.00	3000.00	21
2024-06-05	1	0.00	500.00	-500.00	21
2024-06-07	1	1200.00	0.00	1200.00	21
2024-06-08	2	1500.00	700.00	800.00	21
2024-06-09	2	1000.00	700.00	300.00	21
2024-06-10	1	0.00	3000.00	-3000.00	21
2024-06-11	1	1500.00	0.00	1500.00	21
2024-06-12	2	700.00	1200.00	-500.00	21
2024-06-13	1	0.00	800.00	-800.00	21
2024-06-14	1	700.00	0.00	700.00	21
2024-06-15	4	100.00	4000.00	-3900.00	21
2024-06-16	1	200.00	0.00	200.00	21
2024-06-17	2	0.00	3800.00	-3800.00	21
2024-06-19	2	0.00	1600.00	-1600.00	21
2024-06-22	3	500.00	4000.00	-3500.00	21
2024-06-23	1	3000.00	0.00	3000.00	21
2024-06-26	2	0.00	1200.00	-1200.00	21
2024-06-27	3	700.00	1700.00	-1000.00	21
2024-06-28	1	200.00	0.00	200.00	21
2024-06-29	6	3100.00	2200.00	900.00	21
2024-06-30	2	3000.00	1000.00	2000.00	21
2024-07-02	2	300.00	0.00	300.00	21
2024-07-03	2	200.00	1000.00	-800.00	21
2024-07-05	1	0.00	800.00	-800.00	21
2024-07-06	2	800.00	800.00	0.00	21
2024-07-08	2	800.00	1000.00	-200.00	21
2024-07-09	4	2700.00	200.00	2500.00	21
2024-07-10	1	1200.00	0.00	1200.00	21
2024-07-11	2	4000.00	0.00	4000.00	21
2024-07-12	1	0.00	1200.00	-1200.00	21
2024-07-13	2	2300.00	0.00	2300.00	21
2024-07-14	4	700.00	3900.00	-3200.00	21
2024-07-15	1	0.00	800.00	-800.00	21
2024-07-17	1	0.00	500.00	-500.00	21
2024-07-20	3	700.00	1900.00	-1200.00	21
2024-07-21	1	1500.00	0.00	1500.00	21
2024-07-22	2	200.00	700.00	-500.00	21
2024-07-23	1	0.00	700.00	-700.00	21
2024-07-24	4	200.00	3400.00	-3200.00	21
2024-07-25	4	4200.00	1000.00	3200.00	21
2024-07-26	2	0.00	2300.00	-2300.00	21
2024-07-27	5	1900.00	5000.00	-3100.00	21
2024-07-28	4	2500.00	3800.00	-1300.00	21
2024-07-29	2	1500.00	0.00	1500.00	21
2024-07-30	2	0.00	6000.00	-6000.00	21
2024-07-31	1	0.00	700.00	-700.00	21
2024-08-01	2	1000.00	0.00	1000.00	21
2024-08-02	1	0.00	1200.00	-1200.00	21
2024-08-03	2	1500.00	1000.00	500.00	21
2024-08-06	1	0.00	1200.00	-1200.00	21
2024-08-07	1	1500.00	0.00	1500.00	21
2024-08-08	1	200.00	0.00	200.00	21
2024-08-09	4	2200.00	1700.00	500.00	21
2024-08-10	1	3000.00	0.00	3000.00	21
2024-08-11	2	0.00	1000.00	-1000.00	21
2024-08-12	3	3100.00	800.00	2300.00	21
2024-08-13	1	100.00	0.00	100.00	21
2024-08-14	3	1400.00	3000.00	-1600.00	21
2024-08-15	1	0.00	1500.00	-1500.00	21
2024-08-16	2	800.00	3000.00	-2200.00	21
2024-08-17	5	0.00	7200.00	-7200.00	21
2024-08-19	1	0.00	700.00	-700.00	21
2024-08-20	3	1000.00	1200.00	-200.00	21
2024-08-21	1	0.00	100.00	-100.00	21
2024-08-22	3	200.00	2000.00	-1800.00	21
2024-08-24	1	0.00	100.00	-100.00	21
2024-08-26	1	0.00	1500.00	-1500.00	21
2024-08-27	1	1500.00	0.00	1500.00	21
2024-08-28	2	1300.00	0.00	1300.00	21
2024-08-29	1	0.00	1500.00	-1500.00	21
2024-08-31	1	0.00	1200.00	-1200.00	21
2024-09-01	2	0.00	2700.00	-2700.00	21
2024-09-02	1	0.00	1200.00	-1200.00	21
2024-09-03	1	0.00	200.00	-200.00	21
2024-09-04	1	0.00	700.00	-700.00	21
2024-09-06	2	700.00	1000.00	-300.00	21
2024-09-08	1	0.00	800.00	-800.00	21
2024-09-09	3	900.00	0.00	900.00	21
2024-09-13	2	700.00	200.00	500.00	21
2024-09-15	1	100.00	0.00	100.00	21
2024-09-16	3	2000.00	700.00	1300.00	21
2024-09-17	1	0.00	3000.00	-3000.00	21
2024-09-18	1	1200.00	0.00	1200.00	21
2024-09-19	2	3000.00	700.00	2300.00	21
2024-09-20	1	1000.00	0.00	1000.00	21
2024-09-21	1	200.00	0.00	200.00	21
2024-09-23	1	0.00	1000.00	-1000.00	21
2024-09-25	2	2200.00	0.00	2200.00	21
2024-09-26	2	3200.00	0.00	3200.00	21
2024-09-27	1	800.00	0.00	800.00	21
2024-09-29	2	700.00	700.00	0.00	21
2024-09-30	3	1700.00	800.00	900.00	21
2024-10-01	3	5700.00	0.00	5700.00	21
2024-10-02	3	0.00	3800.00	-3800.00	21
2024-10-03	1	1500.00	0.00	1500.00	21
2024-10-04	1	0.00	800.00	-800.00	21
2024-10-05	2	1500.00	1200.00	300.00	21
2024-10-06	1	800.00	0.00	800.00	21
2024-10-08	1	0.00	3000.00	-3000.00	21
2024-10-09	2	1200.00	3000.00	-1800.00	21
2024-10-10	4	1500.00	5500.00	-4000.00	21
2024-10-11	1	1000.00	0.00	1000.00	21
2024-10-13	1	0.00	3000.00	-3000.00	21
2024-10-14	2	0.00	2000.00	-2000.00	21
2024-10-15	2	3000.00	500.00	2500.00	21
2024-10-16	5	900.00	3700.00	-2800.00	21
2024-10-17	1	0.00	800.00	-800.00	21
2024-10-18	1	0.00	3000.00	-3000.00	21
2024-10-19	1	3000.00	0.00	3000.00	21
2024-10-21	2	700.00	700.00	0.00	21
2024-10-22	2	700.00	3000.00	-2300.00	21
2024-10-23	1	0.00	200.00	-200.00	21
2024-10-24	2	1200.00	700.00	500.00	21
2024-10-25	1	200.00	0.00	200.00	21
2024-10-26	1	0.00	3000.00	-3000.00	21
2024-10-27	1	0.00	1500.00	-1500.00	21
2024-10-29	2	0.00	2300.00	-2300.00	21
2024-10-30	1	1500.00	0.00	1500.00	21
2024-10-31	2	3000.00	500.00	2500.00	21
2024-11-01	1	0.00	1500.00	-1500.00	21
2024-11-04	1	1500.00	0.00	1500.00	21
2024-11-05	1	3000.00	0.00	3000.00	21
2024-11-06	2	700.00	1500.00	-800.00	21
2024-11-07	2	1000.00	3000.00	-2000.00	21
2024-11-08	1	100.00	0.00	100.00	21
2024-11-09	1	1000.00	0.00	1000.00	21
2024-11-10	3	1500.00	1000.00	500.00	21
2024-11-11	3	3500.00	0.00	3500.00	21
2024-11-12	1	700.00	0.00	700.00	21
2024-11-13	3	200.00	900.00	-700.00	21
2024-11-14	1	3000.00	0.00	3000.00	21
2024-11-15	2	200.00	3000.00	-2800.00	21
2024-11-16	1	200.00	0.00	200.00	21
2024-11-17	3	0.00	2700.00	-2700.00	21
2024-11-18	2	3000.00	0.00	3000.00	21
2024-11-19	1	0.00	3000.00	-3000.00	21
2024-11-20	1	0.00	3000.00	-3000.00	21
2024-11-22	3	200.00	2700.00	-2500.00	21
2024-11-23	2	0.00	1200.00	-1200.00	21
2024-11-25	1	200.00	0.00	200.00	21
2024-11-26	2	1000.00	200.00	800.00	21
2024-11-29	2	0.00	2000.00	-2000.00	21
2024-11-30	2	300.00	0.00	300.00	21
2024-12-01	1	0.00	700.00	-700.00	21
2024-12-02	1	1000.00	0.00	1000.00	21
2024-12-04	2	0.00	1800.00	-1800.00	21
2024-12-07	2	1200.00	1000.00	200.00	21
2024-12-09	1	1000.00	0.00	1000.00	21
2024-12-10	1	0.00	1000.00	-1000.00	21
2024-12-11	2	1200.00	3000.00	-1800.00	21
2024-12-12	4	100.00	1400.00	-1300.00	21
2024-12-14	1	1500.00	0.00	1500.00	21
2024-12-16	1	0.00	3000.00	-3000.00	21
2024-12-17	1	0.00	200.00	-200.00	21
2024-12-18	2	3800.00	0.00	3800.00	21
2024-12-20	3	4700.00	0.00	4700.00	21
2024-12-22	1	1000.00	0.00	1000.00	21
2024-12-26	1	0.00	1200.00	-1200.00	21
2024-12-27	1	0.00	1200.00	-1200.00	21
2024-12-29	2	900.00	0.00	900.00	21
2024-12-30	5	3000.00	4000.00	-1000.00	21
\.

COMMIT;
