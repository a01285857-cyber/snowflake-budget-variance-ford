import os
import streamlit as st

st.title("Varianza Ford - Análisis por Área")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()

df_full = session.sql("SELECT * FROM FORD_DB.FINANZAS.VW_VARIANZA_FORD").to_pandas()

trimestres = sorted(df_full["TRIMESTRE"].unique().tolist())
trimestre_sel = st.selectbox("Selecciona un trimestre:", trimestres)

df = df_full[df_full["TRIMESTRE"] == trimestre_sel]

st.dataframe(df)

st.bar_chart(df, x="NOMBRE_AREA", y="VARIANZA")
