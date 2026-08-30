package cl.duoc.bancoxyzbatch.config;

import org.springframework.batch.core.job.Job;
import org.springframework.batch.core.job.parameters.JobParameters;
import org.springframework.batch.core.job.parameters.JobParametersBuilder;
import org.springframework.batch.core.launch.JobOperator;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Locale;

/**
 * Controlo qué Job se ejecuta y registro sus métricas principales.
 * Esto permite repetir las pruebas de rendimiento de forma controlada.
 */
@Component
public class ControlledJobRunner
        implements ApplicationRunner {

    private final JobOperator jobOperator;
    private final List<Job> jobs;
    private final Environment environment;

    public ControlledJobRunner(
            JobOperator jobOperator,
            List<Job> jobs,
            Environment environment
    ) {
        this.jobOperator = jobOperator;
        this.jobs = jobs;
        this.environment = environment;
    }

    @Override
    public void run(ApplicationArguments args)
            throws Exception {

        String requestedJob =
                environment.getProperty(
                        "app.batch.job"
                );

        // Si no se solicita un Job, la aplicación inicia sin ejecutar procesos.
        if (requestedJob == null
                || requestedJob.isBlank()) {

            System.out.println(
                    "[BATCH] Ningún Job solicitado."
            );

            return;
        }

        String runIdValue =
                environment.getProperty(
                        "app.batch.run-id"
                );

        if (runIdValue == null
                || runIdValue.isBlank()) {

            throw new IllegalArgumentException(
                    "Debe indicar "
                            + "--app.batch.run-id=<numero>"
            );
        }

        Long runId;

        try {

            runId =
                    Long.valueOf(
                            runIdValue
                    );

        } catch (NumberFormatException ex) {

            throw new IllegalArgumentException(
                    "app.batch.run-id debe ser "
                            + "un número entero.",
                    ex
            );
        }

        Job job = jobs.stream()
                .filter(candidate ->
                        candidate.getName()
                                .equals(requestedJob)
                )
                .findFirst()
                .orElseThrow(() ->
                        new IllegalArgumentException(
                                "Job no encontrado: "
                                        + requestedJob
                                        + ". Disponibles: "
                                        + obtenerJobsDisponibles()
                        )
                );

        /*
         * El run.id genera una JobInstance distinta
         * y facilita las ejecuciones controladas.
         */
        JobParameters parameters =
                new JobParametersBuilder()
                        .addLong(
                                "run.id",
                                runId
                        )
                        .toJobParameters();

        int threads =
                environment.getProperty(
                        "app.batch.threads",
                        Integer.class,
                        3
                );

        int chunkSize =
                environment.getProperty(
                        "app.batch.chunk-size",
                        Integer.class,
                        5
                );

        long retryMaxRetries =
                environment.getProperty(
                        "app.batch.retry-max-retries",
                        Long.class,
                        3L
                );

        System.out.println(
                "[BATCH] Ejecutando Job: "
                        + job.getName()
        );

        System.out.println(
                "[BATCH] run.id: "
                        + runId
        );

        System.out.println(
                "[BATCH-PERF] configuración"
                        + " | threads="
                        + threads
                        + " | chunkSize="
                        + chunkSize
                        + " | retryMaxRetries="
                        + retryMaxRetries
        );

        // Mido la duración total para comparar configuraciones.
        long inicioNs =
                System.nanoTime();

        var execution =
                jobOperator.start(
                        job,
                        parameters
                );

        long finNs =
                System.nanoTime();

        double duracionMs =
                (finNs - inicioNs)
                        / 1_000_000.0;

        System.out.println(
                "[BATCH] JobExecution ID: "
                        + execution.getId()
        );

        System.out.println(
                "[BATCH] Estado final: "
                        + execution.getStatus()
        );

        System.out.println(
                "[BATCH] Exit status: "
                        + execution.getExitStatus()
        );

        System.out.println(
                "[BATCH-PERF] job="
                        + job.getName()
                        + " | threads="
                        + threads
                        + " | chunkSize="
                        + chunkSize
                        + " | duraciónMs="
                        + String.format(
                                Locale.ROOT,
                                "%.3f",
                                duracionMs
                        )
        );
    }

    private String obtenerJobsDisponibles() {

        return jobs.stream()
                .map(Job::getName)
                .sorted()
                .toList()
                .toString();
    }
}

