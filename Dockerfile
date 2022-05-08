FROM asachet/rocker-tidymodels

# Install required libraries
RUN R -e 'install.packages(c("plumber", "forecast", "yaml", "dplyr", "timetk", "lubridate", "tidymodels", "modeltime"))'

# Copy model and script
RUN mkdir /data
RUN mkdir /config
RUN mkdir /outputs
COPY config/parameters.yaml /config
COPY data/raw.RData /data
COPY get_predictions.R /
COPY outputs/best_model.RData /outputs

# Plumb & run server
EXPOSE 8080
ENTRYPOINT ["R", "-e", \
    "pr <- plumber::plumb('get_predictions.R'); pr$run(host='0.0.0.0', port=8080)"]