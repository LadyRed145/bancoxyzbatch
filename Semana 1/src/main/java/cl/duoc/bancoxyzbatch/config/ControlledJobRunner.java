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
                environment.getProperty("app.batch.job");

        /*
         * Si no se especifica ningún Job,
         * la aplicación arranca normalmente
         * y no ejecuta nada.
         */
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
            runId = Long.valueOf(runIdValue);
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

        JobParameters parameters =
                new JobParametersBuilder()
                        .addLong(
                                "run.id",
                                runId
                        )
                        .toJobParameters();

        System.out.println(
                "[BATCH] Ejecutando Job: "
                        + job.getName()
        );

        System.out.println(
                "[BATCH] run.id: "
                        + runId
        );

        var execution =
                jobOperator.start(
                        job,
                        parameters
                );

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
    }

    private String obtenerJobsDisponibles() {
        return jobs.stream()
                .map(job -> job.getName())
                .sorted()
                .toList()
                .toString();
    }
}
