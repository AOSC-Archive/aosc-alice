use argh::FromArgs;
use sailfish::TemplateOnce;

mod vm;

#[derive(FromArgs)]
/// Small helper program to create a test VM via libvirt
struct TestHelper {
    /// size of VM RAM in bytes (optional, default: 1 GB)
    #[argh(option)]
    ram: Option<usize>,
    /// number of virtual CPUs (optional, default: 2 vCPU)
    #[argh(option)]
    cpu: Option<usize>,
    /// path to the disk image
    #[argh(option)]
    path: String,
    /// use OpenGL for accelerated rendering
    #[argh(switch)]
    gl: bool,
}

fn main() {
    let args: TestHelper = argh::from_env();
    let s = vm::generate_vm_spec(&args.path, args.cpu, args.ram, args.gl).unwrap();
    let name = s.name.clone();
    let nvram = s.nvram.clone();
    vm::create_vm(&s.render_once().unwrap()).unwrap();
    println!("VM created: {}\nNVRAM: {}", name, nvram);
}
