import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from pathlib import Path

# === 1) Percorso file CSV ===
csv_path = Path("dati.csv")

# === 2) Caricamento con pulizia base ===
na_vals = ["", " ", "NA", "N/A", "null", "None", "-", "--"]
df = pd.read_csv(csv_path, na_values=na_vals, keep_default_na=True)

# Normalizza i nomi colonna
df.columns = [c.strip().lower() for c in df.columns]

required = {"p_year", "p_month", "version", "conto"}
missing = required - set(df.columns)
if missing:
    raise ValueError(f"Mancano queste colonne nel file: {missing}")

# === 3) Coercizioni tipi ===
df["p_year"] = pd.to_numeric(df["p_year"], errors="coerce")
df["p_month"] = (
    df["p_month"].astype(str).str.extract(r"(\d+)")[0]
      .astype(float)
)

conto_clean = (
    df["conto"].astype(str).str.strip()
      .str.replace(".", "", regex=False)
      .str.replace(",", ".", regex=False)
)
df["conto"] = pd.to_numeric(conto_clean, errors="coerce")

mask_ok = (
    df["p_year"].between(1900, 2100, inclusive="both") &
    df["p_month"].between(1, 12, inclusive="both") &
    df["conto"].notna()
)
if (~mask_ok).any():
    print("ATTENZIONE: righe escluse per dati non validi:")
    print(df.loc[~mask_ok, ["p_year", "p_month", "version", "conto"]])

df = df.loc[mask_ok].copy()

# === 4) Periodo (inizio mese) ===
period = pd.PeriodIndex.from_fields(year=df["p_year"].astype(int), month=df["p_month"].astype(int), freq="M")
df["Periodo"] = period.to_timestamp(how="start")

# Versione -> stringa
df["version"] = df["version"].astype(str)

# === 5) Aggregazione e pivot ===
agg = df.groupby(["Periodo", "version"], as_index=False)["conto"].sum()
pivot = agg.pivot(index="Periodo", columns="version", values="conto").sort_index()
pivot.index = pd.to_datetime(pivot.index, utc=False)

# === 6) Plot ===
plt.figure(figsize=(14, 6))
ax = plt.gca()

pivot.plot(ax=ax, marker="o")

ax.set_title("Conto per versione nel tempo")
ax.set_xlabel("Periodo (Anno-Mese)")
ax.set_ylabel("Numero notifiche per versione")
ax.grid(True, which="both", linestyle="--", alpha=0.4)

# Imposta esplicitamente TUTTI i mesi come tick dell'asse X
start = pd.Timestamp(pivot.index.min()).to_period('M').to_timestamp(how='start')
end = pd.Timestamp(pivot.index.max()).to_period('M').to_timestamp(how='start')
all_months = pd.date_range(start=start, end=end, freq='MS')  # ogni inizio mese
ax.set_xticks(all_months)

# Etichette mese-anno in italiano (abbr)
abbr = {1:"Gen",2:"Feb",3:"Mar",4:"Apr",5:"Mag",6:"Giu",7:"Lug",8:"Ago",9:"Set",10:"Ott",11:"Nov",12:"Dic"}
labels = [f"{abbr[d.month]}-{d.year % 100:02d}" for d in all_months]
ax.set_xticklabels(labels, rotation=45, ha="right")

# Limiti e linee di gennaio
ax.set_xlim(all_months.min(), all_months.max())
for year in sorted(set(pivot.index.year)):
    jan = pd.Timestamp(year=year, month=1, day=1)
    if all_months.min() <= jan <= all_months.max():
        ax.axvline(jan, linestyle="--", alpha=0.6)

plt.tight_layout()

# === 8) Salvataggio ===
output_png = csv_path.with_name("NotifichePerVersione.png")
plt.savefig(output_png, dpi=160)
print(f"Grafico salvato in: {output_png.resolve()}")

plt.show()
