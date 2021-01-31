from flask import Flask, render_template, request
import logging
from lib.Vaccine import Vaccine
from lib.Infections import Infections
from lib.Decorators import page, endpoint

app = Flask(__name__, static_url_path="")
logging.basicConfig(
    filename="app.log",
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] [%(name)s]: %(message)s",
)

infections = Infections()
vaccines = Vaccine()

# Page routes
@app.route("/")
@page
def index():
    return render_template(
        "index.html",
        summary=infections.summary(),
        last_updated=infections.last_updated(format="%d %B %Y"),
        tab="overview",
    )


@app.route("/vaccine")
@page
def vaccine():
    return render_template(
        "vaccine.html",
        tab="vaccine",
        weekly=vaccines.vaccines_weekly(),
        last_updated=infections.last_updated(format="%d %B %Y"),
    )


@app.route("/locations")
@page
def locations():
    return render_template("locations.html")


# API routes
@app.route("/api/trend")
@endpoint
def trend():
    return infections.trend(request.args)


@app.route("/api/breakdown")
@endpoint
def breakdown():
    return infections.breakdown()


@app.route("/api/locations/total")
@endpoint
def locations_total():
    return infections.locations_total()


@app.route("/api/locations/new")
@endpoint
def locations_new():
    return infections.locations_new()


@app.route("/api/vaccines/weekly")
@endpoint
def vaccines_weekly():
    return vaccines.vaccines_weekly()


@app.route("/api/prevalence")
@endpoint
def prevalence():
    limit = int(request.args["limit"]) if "limit" in request.args else -1
    return infections.prevalence()[0:limit]


if __name__ == "__main__":
    app.run()
