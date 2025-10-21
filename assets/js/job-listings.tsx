import React, { useState, useRef } from "react";
import { createRoot } from "react-dom/client";
import {
  QueryClient,
  QueryClientProvider,
  useQuery,
  useMutation,
} from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "./components/ui/card";
import { Button } from "./components/ui/button";
import { JobHeader } from "./components/job-header";
import { JobFilters } from "./components/job-filters";
import { AIRecommendations } from "./components/ai-recommendations";
import { JobCard } from "./components/job-card";
import { findMatchingJobs, buildCSRFHeaders } from "./ash_rpc";
import type { FindMatchingJobsFields } from "./ash_rpc";
import type { JobCardData, PaginatedResult } from "./types";
import { ChevronLeft, ChevronRight, Sparkles } from "lucide-react";

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5 minutes
      retry: 1,
      refetchOnWindowFocus: false,
      refetchOnReconnect: false,
      refetchOnMount: false,
    },
  },
});

// Custom hook for fetching job listings with AI matching or regular listing
function useJobListings(
  page: number,
  pageSize: number = 25,
  idealJobDescription?: string,
): {
  data: PaginatedResult<JobCardData> | undefined;
  isLoading: boolean;
  error: Error | null;
} {
  return useQuery({
    queryKey: ["jobListings", page, pageSize, idealJobDescription],
    queryFn: async (): Promise<PaginatedResult<JobCardData>> => {
      const headers = buildCSRFHeaders();

      if (idealJobDescription && idealJobDescription.trim().length > 0) {
        // Use AI matching when ideal job description is provided
        const fields: FindMatchingJobsFields = [
          "id",
          "jobRoleName",
          "description",
          "companyId",
        ];

        // Use raw RPC call since generated function doesn't support custom arguments
        const payload = {
          action: "find_matching_jobs",
          fields: fields,
          arguments: { 
            ideal_job_description: idealJobDescription,
            limit: pageSize 
          }
        };

        const response = await fetch("/rpc/run", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...headers
          },
          body: JSON.stringify(payload)
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const matchingJobs = await response.json();

        if (!matchingJobs.success) {
          throw new Error(
            matchingJobs.errors?.map((e: any) => e.message).join(", ") ||
              "Failed to find matching jobs",
          );
        }

        const data = matchingJobs.data?.results || [];
        console.log('Raw backend response:', JSON.stringify(matchingJobs.data, null, 2));
        console.log('First job raw data:', JSON.stringify(data[0], null, 2));
        
        const results: JobCardData[] = data.map((job: any) => ({
          id: job.id,
          jobRoleName: job.jobRoleName,
          jobDescription: job.description,
          description: job.description,
          companyId: job.companyId,
          matchScore: job.matchScore || job.match_score || 0,
        }));
        
        console.log('First processed job:', results[0]);

        return { results, hasMore: false, count: results.length };
      } else {
        // When no ideal description is provided, return no jobs
        return { results: [], hasMore: false, count: 0 };
      }
    },
    retry: 1,
    staleTime: 30000, // 30 seconds
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
    refetchOnMount: false,
  });
}

// Moved JobRequirements UI into components/job-requirements.tsx

// Deprecated local JobListingCard; replaced by components/JobCard

// Pagination component
function Pagination({
  currentPage,
  totalPages,
  hasMore,
  onPageChange,
}: {
  currentPage: number;
  totalPages: number | null;
  hasMore: boolean;
  onPageChange: (page: number) => void;
}) {
  return (
    <div className="flex items-center justify-between px-2 py-4">
      <div className="flex-1 text-sm text-muted-foreground">
        Showing page {currentPage} {totalPages && `of ${totalPages}`}
      </div>

      <div className="flex items-center space-x-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => onPageChange(currentPage - 1)}
          disabled={currentPage === 1}
          className="flex items-center gap-1"
        >
          <ChevronLeft className="w-4 h-4" />
          Previous
        </Button>

        <Button
          variant="outline"
          size="sm"
          onClick={() => onPageChange(currentPage + 1)}
          disabled={!hasMore}
          className="flex items-center gap-1"
        >
          Next
          <ChevronRight className="w-4 h-4" />
        </Button>
      </div>
    </div>
  );
}

// Main JobListings component
function JobListings() {
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 25;

  const idealDescRef = useRef("");
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // const updateIdealJobDescription = useMutation({
  //   mutationFn: async (desc: string) => {
  //     const headers = buildCSRFHeaders({ "Content-Type": "application/json" });
  //     const payload = {
  //       action: "update_ideal_job_description",
  //       arguments: { ideal_job_description: desc },
  //     } as const;
  //     const res = await fetch("/rpc/run", {
  //       method: "POST",
  //       headers,
  //       body: JSON.stringify(payload),
  //     });
  //     if (!res.ok) {
  //       throw new Error(res.statusText);
  //     }
  //     const json = await res.json();
  //     if (json?.success === false) {
  //       throw new Error(
  //         json.errors?.map((e: any) => e.message).join(", ") || "Failed",
  //       );
  //     }
  //     return json;
  //   },
  // });

  const [queryKey, setQueryKey] = useState("");

  const { data, isLoading, error, refetch } = useJobListings(
    currentPage,
    pageSize,
    queryKey,
  );
  console.log("JobListings component - data:", data);

  const totalPages = data?.count ? Math.ceil(data.count / pageSize) : null;

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-accent/5 to-background">
        <JobHeader />
        <div className="container mx-auto px-4 py-8">
          <div className="mb-8">
            <div className="h-8 bg-muted rounded w-64 mb-4 animate-pulse"></div>
            <div className="h-4 bg-muted rounded w-96 animate-pulse"></div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
            <aside className="lg:col-span-1">
              <div className="space-y-2">
                <div className="h-6 bg-muted rounded w-1/2"></div>
                <div className="h-6 bg-muted rounded w-1/3"></div>
              </div>
            </aside>
            <main className="lg:col-span-3 space-y-6">
              <div className="h-32 bg-muted rounded"></div>
              <div className="grid gap-6">
                {[1, 2, 3, 4, 5].map((i) => (
                  <Card key={i} className="animate-pulse">
                    <CardHeader>
                      <div className="h-6 bg-muted rounded w-3/4 mb-2"></div>
                      <div className="h-4 bg-muted rounded w-1/2"></div>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-2">
                        <div className="h-4 bg-muted rounded w-full"></div>
                        <div className="h-4 bg-muted rounded w-5/6"></div>
                        <div className="h-4 bg-muted rounded w-4/6"></div>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </main>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-accent/5 to-background">
        <JobHeader />
        <div className="container mx-auto px-4 py-8">
          <Card className="border-destructive/30 bg-destructive/10">
            <CardHeader>
              <CardTitle className="text-destructive">
                Erro carregando vagas disponíveis
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-destructive/90">{(error as Error).message}</p>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-accent/5 to-background">
      <JobHeader />
      <div className="container mx-auto px-4 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          <aside className="lg:col-span-1">
            <JobFilters />
          </aside>
          <main className="lg:col-span-3 space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Seu objetivo profissional</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <textarea
                  ref={textareaRef}
                  rows={4}
                  placeholder="Descreva a vaga ideal para você (ex.: área, senioridade, tecnologias, tipo de trabalho)"
                  className="w-full rounded-md border bg-background p-3 text-sm outline-none focus:ring-2 focus:ring-primary/50"
                />
                <div className="flex items-center gap-2 flex-wrap">
                  <Button
                    onClick={() => {
                      const desc = textareaRef.current?.value || "";
                      idealDescRef.current = desc;
                      setQueryKey(desc);
                    }}
                    disabled={isLoading}
                  >
                    <Sparkles className="h-3.5 w-3.5 mr-1.5" />
                    Buscar vagas compatíveis
                  </Button>

                  {/*
                  {updateIdealJobDescription.isPending && (
                    <span className="text-sm text-muted-foreground">
                      Salvando...
                    </span>
                  )}
                  {updateIdealJobDescription.isSuccess && (
                    <span className="text-sm text-green-600">Salvo!</span>
                  )}
                  {updateIdealJobDescription.isError && (
                    <span className="text-sm text-destructive">
                      {(updateIdealJobDescription.error as Error)?.message}
                    </span>
                  )}

                  {isLoading && idealDesc.trim().length > 0 && (
                    <span className="text-sm text-muted-foreground">
                      🔍 Buscando vagas compatíveis...
                    </span>
                  )}
                  */}
                </div>
              </CardContent>
            </Card>
            <AIRecommendations description="placeholder" />
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-2xl font-semibold text-foreground">
                  {queryKey.trim().length > 0 ? (
                    <div className="flex items-center gap-2">
                      <Sparkles className="h-6 w-6 text-primary" />
                      Vagas Recomendadas por IA
                    </div>
                  ) : (
                    "Vagas"
                  )}
                </h2>
                <p className="text-sm text-muted-foreground">
                  {queryKey.trim().length > 0
                    ? `${data?.results?.length ?? 0} vagas recomendadas`
                    : `0 vagas`}
                </p>
              </div>
              <div className="space-y-4">
                {queryKey.trim().length > 0 ? (
                  data &&
                  data.results &&
                  Array.isArray(data.results) &&
                  data.results.length > 0 ? (
                    data.results.map((job) => (
                      <JobCard
                        key={job.id}
                        job={job}
                        matchScore={job.matchScore || 0}
                      />
                    ))
                  ) : (
                    <Card className="text-center py-16">
                      <CardHeader>
                        <CardTitle className="text-2xl text-muted-foreground">
                          <Sparkles className="h-8 w-8 mx-auto mb-2 text-primary" />
                          Nenhuma vaga compatível encontrada
                        </CardTitle>
                      </CardHeader>
                      <CardContent>
                        <p className="text-muted-foreground mb-4">
                          Digite sua descrição ideal e clique em "Encontrar
                          vagas compatíveis".
                        </p>
                      </CardContent>
                    </Card>
                  )
                ) : (
                  <Card className="text-center py-16">
                    <CardHeader>
                      <CardTitle className="text-2xl text-muted-foreground">
                        Nenhuma vaga
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      <p className="text-muted-foreground mb-4">
                        Digite sua descrição ideal para ver vagas recomendadas
                        por IA.
                      </p>
                    </CardContent>
                  </Card>
                )}
              </div>

              {/* Pagination */}
              <Pagination
                currentPage={currentPage}
                totalPages={totalPages}
                hasMore={!!data?.hasMore}
                onPageChange={setCurrentPage}
              />
            </div>
          </main>
        </div>
      </div>
    </div>
  );
}

// App component with QueryClient provider
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <JobListings />
    </QueryClientProvider>
  );
}

// Mount the app
const root = createRoot(document.getElementById("app")!);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
