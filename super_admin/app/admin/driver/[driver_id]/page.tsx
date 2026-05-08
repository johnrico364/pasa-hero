import DriverDetailsClient from "./_components/DriverDetailsClient";

export default async function DriverDetailsPage({
  params,
}: {
  params: Promise<{ driver_id: string }>;
}) {
  const { driver_id } = await params;
  return <DriverDetailsClient driverId={driver_id} />;
}
