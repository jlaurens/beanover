import plotly.express as px
import pandas as pd
import plotly.io as pio

pio.renderers.default = "browser"
df = pd.read_csv("profiling.csv")

parent_queue = ["total"]
parents = [""]
prev_scope = 0
for row in df.iloc[1:,:].itertuples():
    if row.Scope == prev_scope:
        parent_queue.pop()
        parents.append(parent_queue[-1])
        parent_queue.append(row.Tag)
    elif row.Scope > prev_scope:
        parents.append(parent_queue[-1])
        parent_queue.append(row.Tag)
    elif row.Scope < prev_scope:
        parent_queue = parent_queue[:row.Scope]
        parents.append(parent_queue[-1])
        parent_queue.append(row.Tag)

    prev_scope = row.Scope

# insert parent column as second column
df.insert(1, "Parent", parents)

# generate column that contains tag without the call count
df['Type'] = df['Tag'].str.replace(r"(.*)/\d+$", r"\1", regex=True)

fig = px.sunburst(
    df,
    names='Tag',
    parents='Parent',
    values='Difference',
    color='Type',
)
fig.show()
