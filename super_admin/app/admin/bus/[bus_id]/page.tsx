import BusDetailsClient from "./_components/BusDetailsClient";

export default async function BusInformationPage({
  params,
}: {
  params: Promise<{ bus_id: string }>;
}) {
  const { bus_id } = await params;
  return <BusDetailsClient busId={bus_id} />;
}
